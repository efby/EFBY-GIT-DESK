import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

struct TreeNavigationTests {
    @Test func folderExpansionRestoresPerRepositoryAndToggleAllPreservesHiddenFolders() async throws {
        let fixture = try await GitFixture.make(); defer { fixture.cleanup() }
        let registry = try SQLiteRegistry(path: fixture.folder.appendingPathComponent("expansion.sqlite").path)
        let first = FolderExpansionPreference.key(scope: "comparison", repositoryID: "/one/project")
        let second = FolderExpansionPreference.key(scope: "comparison", repositoryID: "/two/project")
        #expect(first != second)
        let collapsed: Set<String> = ["folder:src", "folder:hidden"]
        try await registry.setPreference(first, value: #require(FolderExpansionPreference.encode(collapsed)))
        #expect(FolderExpansionPreference.decode(try await registry.preference(first)) == collapsed)
        #expect(FolderExpansionPreference.decode(try await registry.preference(second)).isEmpty)
        let visible: Set<String> = ["folder:src", "folder:test"]
        let expanded = FolderExpansionPreference.toggleAll(collapsed: collapsed, visible: visible)
        #expect(expanded == ["folder:hidden"])
        #expect(FolderExpansionPreference.allExpanded(collapsed: expanded, visible: visible))
        #expect(FolderExpansionPreference.toggleAll(collapsed: expanded, visible: visible) == ["folder:hidden", "folder:src", "folder:test"])
    }

    @Test func indexesPythonTypeScriptAndDartDeclarationsWithoutCommentsOrStrings() {
        let python = """
        # def hidden():
        def first():
            pass
        async def fetch_data():
            pass
        class Reader:
            def read(self):
                pass
        """
        let pythonSymbols = CodeSymbolIndex.make(text: python, language: .python)
        #expect(pythonSymbols.map(\.name) == ["first", "fetch_data", "Reader", "read"])
        #expect(pythonSymbols.first { $0.name == "read" }?.owner == "Reader")
        let typescript = """
        // function hidden() {}
        export async function loadData() {}
        export const refresh = async (id: string) => id;
        class Client {
          public save() { return true; }
        }
        """
        #expect(CodeSymbolIndex.make(text: typescript, language: .typescript).map(\.name) == ["loadData", "refresh", "Client", "save"])
        let typed = """
        export const loadRows = async (id: string): Promise<string> => id;
        class Api {
          async query<T>(
            input: string
          ): Promise<T> {
            return input as T;
          }
        }
        """
        #expect(CodeSymbolIndex.make(text: typed, language: .typescript).map(\.name) == ["loadRows", "Api", "query"])
        let calls = [DiffRow(before: nil, after: "    api?.query<User>(", beforeNumber: nil, afterNumber: 4)]
        let declaration = CodeDeclaration(fileID: "api", path: "src/api.ts", name: "query", line: 3, before: false)
        let links = CodeCallIndex.links(rows: calls, beforeLanguage: .typescript, afterLanguage: .typescript,
                                        declarations: [declaration], currentFileID: "caller")
        #expect(links.after[0].map(\.name) == ["query"])
        let dart = """
        /* void hidden() {} */
        Future<String> fetch() async {
          return 'ok';
        }
        class Service {
          void save() => print('ok');
        }
        """
        #expect(CodeSymbolIndex.make(text: dart, language: .dart).map(\.name) == ["fetch", "Service", "save"])
        #expect(CodeLanguage.detect(path: "lib/service.dart") == .dart)
        #expect(CodeSymbolIndex.make(text: String(repeating: "x", count: 2_000_001), language: .dart).isEmpty)
    }

    @Test func viewerLinksAQualifiedCallAndLeavesAmbiguousNamesPlain() throws {
        let query = CodeDeclaration(fileID: "db", path: "src/dynamodb.py", name: "query_objects", line: 1, before: false)
        let run = CodeDeclaration(fileID: "worker", path: "src/worker.py", name: "run", line: 1, before: false)
        let other = CodeDeclaration(fileID: "other", path: "lib/tasks.py", name: "run", line: 4, before: false)
        let rows = [
            DiffRow(before: "    dynamodb.query_objects(", after: "    dynamodb.query_objects(", beforeNumber: 2, afterNumber: 2),
            DiffRow(before: "    run(", after: "    run(", beforeNumber: 3, afterNumber: 3),
            DiffRow(before: "# dynamodb.query_objects(", after: "# dynamodb.query_objects(", beforeNumber: 4, afterNumber: 4)
        ]
        let links = CodeCallIndex.links(rows: rows, beforeLanguage: .python, afterLanguage: .python,
                                        declarations: [query, run], currentFileID: "caller")
        #expect(links.before == [[], [], []])
        #expect(links.after[0].map(\.fileID) == ["db"])
        #expect(links.after[1].map(\.fileID) == ["worker"])
        #expect(links.after[2].isEmpty)
        let ambiguous = CodeCallIndex.links(rows: rows, beforeLanguage: .python, afterLanguage: .python,
                                            declarations: [query, run, other], currentFileID: "caller")
        #expect(ambiguous.after[1].isEmpty)
        let definition = [DiffRow(before: nil, after: "def query_objects(", beforeNumber: nil, afterNumber: 1)]
        let sameLine = CodeCallIndex.links(rows: definition, beforeLanguage: .python, afterLanguage: .python,
                                           declarations: [query], currentFileID: "db")
        #expect(sameLine.after[0].isEmpty)
        let service = CodeDeclaration(fileID: "pago", path: "src/app/services/pago-click.service.ts", name: "postLiberar", line: 20, before: false)
        let duplicate = CodeDeclaration(fileID: "otro", path: "src/app/services/otro.service.ts", name: "postLiberar", line: 8, before: false)
        let member = [DiffRow(before: nil, after: "    this.pagoClickService.postLiberar(", beforeNumber: nil, afterNumber: 4)]
        let memberLinks = CodeCallIndex.links(rows: member, beforeLanguage: .typescript, afterLanguage: .typescript,
                                              declarations: [service, duplicate], currentFileID: "component")
        #expect(memberLinks.after[0].map(\.fileID) == ["pago"])
        #expect(CodeCallIndex.callNames(rows: member, beforeLanguage: .typescript, afterLanguage: .typescript) == ["postLiberar"])
        let classFile = CodeDeclaration(fileID: "class", path: "src/PagoClickService.ts", name: "postLiberar", line: 3, before: false)
        let classLinks = CodeCallIndex.links(rows: member, beforeLanguage: .javascript, afterLanguage: .javascript,
                                             declarations: [classFile, duplicate], currentFileID: "component")
        #expect(classLinks.after[0].map(\.fileID) == ["class"])
        let source = """
        import { PagoClickService } from '../services/pago-click.service';
        import { postLiberar } from './otro';
        """
        let imports = CodeImportIndex.bindings(in: source, language: .typescript, filePath: "src/app/component.ts")
        let imported = CodeDeclaration(fileID: "pago", path: "src/services/pago-click.service.ts", name: "postLiberar", line: 12, before: false)
        let elsewhere = CodeDeclaration(fileID: "otro", path: "src/app/otro.ts", name: "postLiberar", line: 2, before: false)
        let call = [DiffRow(before: nil, after: "    this.pagoClickService.postLiberar(", beforeNumber: nil, afterNumber: 8)]
        let resolved = CodeCallIndex.links(rows: call, beforeLanguage: .typescript, afterLanguage: .typescript,
                                           declarations: [imported, elsewhere], currentFileID: "component", imports: imports)
        #expect(resolved.after[0].map(\.fileID) == ["pago"])
        let named = [DiffRow(before: nil, after: "    postLiberar(", beforeNumber: nil, afterNumber: 9)]
        let alias = CodeCallIndex.links(rows: named, beforeLanguage: .typescript, afterLanguage: .typescript,
                                        declarations: [imported, elsewhere], currentFileID: "component", imports: imports)
        #expect(alias.after[0].map(\.fileID) == ["otro"])
        let python = CodeImportIndex.bindings(in: "from . import dynamodb\n", language: .python, filePath: "src/caller.py")
        #expect(CodeImportIndex.moduleMatches(file: "src/dynamodb.py", module: python["dynamodb"] ?? ""))
        let payment = """
        class Payment:
            def charge(self):
                return 1
            def pay(self):
                self.charge()
        class Other:
            def charge(self):
                return 2
        """
        let paymentSymbols = CodeSymbolIndex.make(text: payment, language: .python)
        let paymentCharge = try #require(paymentSymbols.first { $0.name == "charge" && $0.owner == "Payment" })
        let otherCharge = try #require(paymentSymbols.first { $0.name == "charge" && $0.owner == "Other" })
        let paymentDeclarations = [
            CodeDeclaration(fileID: "payment", path: "src/payment.py", name: "charge", line: paymentCharge.line, before: false, owner: "Payment"),
            CodeDeclaration(fileID: "payment", path: "src/payment.py", name: "charge", line: otherCharge.line, before: false, owner: "Other")
        ]
        let selfCall = [DiffRow(before: nil, after: "        self.charge(", beforeNumber: nil, afterNumber: 5)]
        let selfLinks = CodeCallIndex.links(rows: selfCall, beforeLanguage: .python, afterLanguage: .python,
                                            declarations: paymentDeclarations, currentFileID: "payment",
                                            classes: CodeSymbolIndex.classSpans(text: payment, language: .python))
        #expect(selfLinks.after[0].map(\.line) == [paymentCharge.line])
        let pythonScope = CodeImportIndex.scope(in: "from services.gateway import GetnetClient\nclient = GetnetClient()\n", language: .python, filePath: "src/pay.py")
        #expect(pythonScope.receivers["client"] == "GetnetClient")
        let scriptScope = CodeImportIndex.scope(in: "import { GetnetClient } from '../services/gateway';\nconst client = new GetnetClient();\n", language: .typescript, filePath: "src/app/pay.ts")
        #expect(scriptScope.receivers["client"] == "GetnetClient")
        let dartScope = CodeImportIndex.scope(in: "import 'package:app/services/gateway.dart';\nfinal client = GetnetClient();\n", language: .dart, filePath: "lib/pay.dart")
        #expect(dartScope.receivers["client"] == "GetnetClient")
        let gateway = CodeDeclaration(fileID: "gateway", path: "src/services/gateway.ts", name: "charge", line: 4, before: false)
        let another = CodeDeclaration(fileID: "another", path: "src/other.ts", name: "charge", line: 2, before: false)
        let instanceCall = [DiffRow(before: nil, after: "client.charge(", beforeNumber: nil, afterNumber: 3)]
        for scope in [pythonScope, scriptScope] {
            let resolved = CodeCallIndex.links(rows: instanceCall, beforeLanguage: .typescript, afterLanguage: .typescript,
                                               declarations: [gateway, another], currentFileID: "pay", imports: scope.imports, receivers: scope.receivers)
            #expect(resolved.after[0].map(\.fileID) == ["gateway"])
        }
        let dartGateway = CodeDeclaration(fileID: "dart", path: "lib/services/gateway.dart", name: "charge", line: 8, before: false)
        let dartLinks = CodeCallIndex.links(rows: instanceCall, beforeLanguage: .dart, afterLanguage: .dart,
                                            declarations: [dartGateway, another], currentFileID: "pay", imports: dartScope.imports, receivers: dartScope.receivers, libraries: dartScope.libraries)
        #expect(dartLinks.after[0].map(\.fileID) == ["dart"])
        #expect(!CodeCallIndex.isDeclarationLine("getnet = Getnet()", name: "Getnet"))
        #expect(CodeCallIndex.isDeclarationLine("class Getnet(Base):", name: "Getnet"))
        #expect(CodeCallIndex.isDeclarationLine("    def set_error(self, code):", name: "set_error"))
        #expect(!CodeCallIndex.isDeclarationLine("    log.set_error(", name: "set_error"))
        let getnet = CodeDeclaration(fileID: "getnet", path: "src/getnet.py", name: "Getnet", line: 1, before: false, isType: true)
        let constructed = [DiffRow(before: nil, after: "getnet = Getnet(", beforeNumber: nil, afterNumber: 25)]
        let classLink = CodeCallIndex.links(rows: constructed, beforeLanguage: .python, afterLanguage: .python,
                                            declarations: [getnet], currentFileID: "handler")
        #expect(classLink.after[0].map(\.name) == ["Getnet"])
        let logClass = CodeDeclaration(fileID: "log", path: "src/log.py", name: "Log", line: 1, before: false, isType: true)
        let setError = CodeDeclaration(fileID: "log", path: "src/log.py", name: "set_error", line: 4, before: false)
        let otherError = CodeDeclaration(fileID: "other", path: "src/other.py", name: "set_error", line: 2, before: false)
        let handler = "log = Log()\n"
        let handlerScope = CodeImportIndex.scope(in: handler, language: .python, filePath: "src/handler.py")
        let calls = [
            DiffRow(before: nil, after: "log = Log(", beforeNumber: nil, afterNumber: 20),
            DiffRow(before: nil, after: "log.set_error(", beforeNumber: nil, afterNumber: 51)
        ]
        let logged = CodeCallIndex.links(rows: calls, beforeLanguage: .python, afterLanguage: .python,
                                         declarations: [logClass, setError, otherError], currentFileID: "handler", receivers: handlerScope.receivers)
        #expect(logged.after[0].map(\.fileID) == ["log"])
        #expect(logged.after[1].map(\.name) == ["set_error"])
        #expect(logged.after[1].map(\.fileID) == ["log"])
        let message = CodeDeclaration(fileID: "input", path: "src/lambda_input_message.py", name: "LambdaInputMessage", line: 1, before: false, isType: true)
        let carga = CodeDeclaration(fileID: "input", path: "src/lambda_input_message.py", name: "carga", line: 8, before: false)
        let otherCarga = CodeDeclaration(fileID: "other", path: "src/other.py", name: "carga", line: 3, before: false)
        let qualified = [DiffRow(before: nil, after: "jInput = LambdaInputMessage.carga(", beforeNumber: nil, afterNumber: 15)]
        let opened = CodeCallIndex.links(rows: qualified, beforeLanguage: .python, afterLanguage: .python,
                                         declarations: [message, carga, otherCarga], currentFileID: "handler")
        #expect(opened.after[0].map(\.name) == ["LambdaInputMessage", "carga"])
        #expect(opened.after[0].map(\.fileID) == ["input", "input"])
        #expect(opened.after[0].map(\.line) == [1, 8])
        let dynamoClass = CodeDeclaration(fileID: "dynamo", path: "src/dynamo_db.py", name: "DynamoDb", line: 1, before: false, isType: true)
        let dynamoOnClassLine = CodeDeclaration(fileID: "dynamo", path: "src/dynamo_db.py", name: "obtiene_datos_preautorizacion", line: 1, before: false)
        let dynamoMethod = CodeDeclaration(fileID: "dynamo", path: "src/dynamo_db.py", name: "obtiene_datos_preautorizacion", line: 42, before: false, owner: "DynamoDb")
        let dynamoCall = [DiffRow(before: nil, after: "respuesta_obtiene_datos_preautorizacion = DynamoDb.obtiene_datos_preautorizacion(", beforeNumber: nil, afterNumber: 270)]
        let dynamoLinks = CodeCallIndex.links(rows: dynamoCall, beforeLanguage: .python, afterLanguage: .python,
                                              declarations: [dynamoClass, dynamoOnClassLine, dynamoMethod], currentFileID: "handler")
        #expect(dynamoLinks.after[0].map(\.name) == ["DynamoDb", "obtiene_datos_preautorizacion"])
        #expect(dynamoLinks.after[0].map(\.line) == [1, 42])
        let classRange = dynamoLinks.after[0][0].range
        let methodRange = dynamoLinks.after[0][1].range
        #expect(NSIntersectionRange(classRange, methodRange).length == 0)
        let component = """
        import { PagoClickService } from '../services/renamed-payment.service';
        import { ChangeDetectorRef } from '@angular/core';
        import { Store, AppCustomState } from '../store/app.store';
        import { Router } from '@angular/router';
        import { MatDialog } from '@angular/material/dialog';
        constructor(
            private pagoClickService: PagoClickService,
            private cdr: ChangeDetectorRef,
            private store: Store<AppCustomState>,
            private router: Router,
            private modal: MatDialog) { }
        """
        let componentScope = CodeImportIndex.scope(in: component, language: .typescript, filePath: "src/app/pay.component.ts")
        #expect(componentScope.receivers["this.pagoclickservice"] == "PagoClickService")
        #expect(componentScope.receivers["this.store"] == "Store")
        let renamed = CodeDeclaration(fileID: "renamed", path: "src/services/renamed-payment.service.ts", name: "PagoClickService", line: 3, before: false, isType: true)
        let stale = CodeDeclaration(fileID: "stale", path: "src/services/pago-click.service.ts", name: "PagoClickService", line: 1, before: false, isType: true)
        let renamedMethod = CodeDeclaration(fileID: "renamed", path: "src/services/renamed-payment.service.ts", name: "postLiberar", line: 12, before: false)
        let staleMethod = CodeDeclaration(fileID: "stale", path: "src/services/pago-click.service.ts", name: "postLiberar", line: 4, before: false)
        let parameter = [DiffRow(before: nil, after: "        private pagoClickService: PagoClickService,", beforeNumber: nil, afterNumber: 33)]
        let parameterLinks = CodeCallIndex.links(rows: parameter, beforeLanguage: .typescript, afterLanguage: .typescript,
                                                 declarations: [renamed, stale], currentFileID: "component", imports: componentScope.imports, receivers: componentScope.receivers)
        #expect(parameterLinks.after[0].map(\.name) == ["PagoClickService"])
        #expect(parameterLinks.after[0].map(\.fileID) == ["renamed"])
        let generic = [DiffRow(before: nil, after: "        private store: Store<AppCustomState>,", beforeNumber: nil, afterNumber: 35)]
        let store = CodeDeclaration(fileID: "store", path: "src/store/app.store.ts", name: "Store", line: 2, before: false, isType: true)
        let state = CodeDeclaration(fileID: "store", path: "src/store/app.store.ts", name: "AppCustomState", line: 8, before: false, isType: true)
        let genericLinks = CodeCallIndex.links(rows: generic, beforeLanguage: .typescript, afterLanguage: .typescript,
                                               declarations: [store, state], currentFileID: "component", imports: componentScope.imports)
        #expect(genericLinks.after[0].map(\.name) == ["Store", "AppCustomState"])
        let use = [DiffRow(before: nil, after: "    this.pagoClickService.postLiberar(", beforeNumber: nil, afterNumber: 40)]
        let useLinks = CodeCallIndex.links(rows: use, beforeLanguage: .typescript, afterLanguage: .typescript,
                                           declarations: [renamed, stale, renamedMethod, staleMethod], currentFileID: "component", imports: componentScope.imports, receivers: componentScope.receivers)
        #expect(useLinks.after[0].map(\.fileID) == ["renamed"])
        let audit = """
        import { AuditLog } from '../logs/renamed-log';
        constructor(private readonly audit: AuditLog) {}
        """
        let auditScope = CodeImportIndex.scope(in: audit, language: .typescript, filePath: "src/app/other.component.ts")
        #expect(auditScope.receivers["this.audit"] == "AuditLog")
        #expect(CodeCallIndex.isDeclarationLine("    async write(", name: "write"))
        #expect(!CodeCallIndex.isDeclarationLine("    this.audit.write(", name: "write"))
        let auditClass = CodeDeclaration(fileID: "log", path: "src/logs/renamed-log.ts", name: "AuditLog", line: 1, before: false, isType: true)
        let firstWrite = CodeDeclaration(fileID: "log", path: "src/logs/renamed-log.ts", name: "write", line: 4, before: false)
        let overload = CodeDeclaration(fileID: "log", path: "src/logs/renamed-log.ts", name: "write", line: 9, before: false)
        let otherWrite = CodeDeclaration(fileID: "audit", path: "src/audit.ts", name: "write", line: 2, before: false)
        let auditCall = [DiffRow(before: nil, after: "    this.audit.write(", beforeNumber: nil, afterNumber: 18)]
        let auditLinks = CodeCallIndex.links(rows: auditCall, beforeLanguage: .typescript, afterLanguage: .typescript,
                                             declarations: [auditClass, firstWrite, overload, otherWrite], currentFileID: "other", imports: auditScope.imports, receivers: auditScope.receivers)
        #expect(auditLinks.after[0].map(\.fileID) == ["log"])
        #expect(auditLinks.after[0].map(\.line) == [4])
        let pythonClient = CodeImportIndex.scope(in: "from pkg import Client\n    def __init__(self, client: Client):\n", language: .python, filePath: "src/pay.py")
        #expect(pythonClient.receivers["self.client"] == "Client")
        let dartClient = CodeImportIndex.scope(in: "final AuditLog audit;\n", language: .dart, filePath: "lib/pay.dart")
        #expect(dartClient.receivers["this.audit"] == "AuditLog")
    }
}
