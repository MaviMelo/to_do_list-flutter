# TO DO LIST - Flutter

Aplicativo mobile de lista de tarefas (to-do) com persistência em SQLite, categorias,
filtros e notificações locais agendadas. Implementado em **Flutter** (Dart), conforme a
especificação em `../PROMPT.md` (fase 2 da atividade; fase 1 em Kotlin Multiplatform
em `../todo-kmp/`).

> Diário de desenvolvimento: veja [BUILD_LOG.md](BUILD_LOG.md) (append-only, parte da avaliação).

---

# Mobile App Reverse-Engineering Questions

Respostas baseadas no código real de `todo-flutter/`.

---

## 1. Project Structure

O projeto é um app Flutter single-package (`--org com.example --project-name
to_do_flutter --platforms android`), organizado por camada:

- **`lib/models.dart`** — modelos puros: `Task` (id, title, description, completed,
  dueDateTime, createdAt, categoryId) e `Category` (id, name, color) com
  `fromMap`/`toMap`/`copyWith`, e `TaskWithCategory` (task + categoria resolvida).
- **`lib/todo_database.dart`** — SQLite direto via **sqflite** (sem ORM): cria o banco
  `todo.db` em `getDatabasesPath()` com as tabelas `Category` e `Task` (FK
  `categoryId → Category(id) ON DELETE SET NULL` + índice) e concentra todo o SQL
  (CRUD de tarefas e categorias, ordenações).
- **`lib/todo_repository.dart`** — regras sobre o banco: paleta de 10 cores Material
  para categorias novas, `notificationIdFor(taskId) = 100000 + taskId` (vínculo
  determinístico tarefa ↔ notificação).
- **`lib/todo_notifier.dart`** — notificações locais via **flutter_local_notifications
  19.5.0 + timezone**: init, permissão (API 33+), `zonedSchedule` e cancel.
- **`lib/todo_store.dart`** — estado global (`TodoStore extends ChangeNotifier`):
  tarefas, categorias, filtros de status/categoria e todas as operações (criar,
  editar, concluir, excluir, categorias).
- **`lib/main.dart`** — entry point: monta database → repository → notifier → store
  e chama `runApp(TodoApp(store: store))`.
- **`lib/ui/`** — telas: `app.dart` (navegação + tema), `task_list_screen.dart`
  (lista + filtros + sair), `task_editor_screen.dart` (form de criação/edição),
  `categories_screen.dart` (CRUD de categorias), `category_dropdown.dart`.
- **`test/models_test.dart`** — 6 testes unitários de modelos/paleta/IDs.

Organização: dados (sqflite) → repository → store (ChangeNotifier) → telas; sem
injeção de dependências por framework — as dependências são criadas em `main()` e
passadas por construtor.

---

## 2. Architecture and State

**MVVM-like** com **ChangeNotifier** (pacote `provider`) e UI reativa via
`ListenableBuilder`.

- Um único store (`TodoStore`) centraliza o estado: `_tasks`, `_categories`,
  `_filter` (enum `TaskFilter { all, pending, completed }`), `_categoryFilter` e
  `_loading`.
- As telas escutam com `ListenableBuilder(listenable: store, ...)` — qualquer
  `notifyListeners()` reconstrói a tela.
- **Refresh determinístico:** toda operação de escrita termina com `await load()`,
  que recarrega tarefas e categorias do banco e chama `notifyListeners()`. A UI
  nunca assume o resultado da escrita — sempre relê do SQLite (mesma filosofia do
  KMP, onde a invalidação automática do driver se mostrou pouco confiável).
- **Criar/editar tarefa:** a tela de editor recebe apenas o `taskId` e carrega o
  objeto do banco via `store.repositoryTaskById()` (acesso pontual fora do ciclo de
  notificação); ao salvar chama `store.saveTask(...)` → INSERT/UPDATE → `load()` →
  a lista reaparece atualizada ao voltar (navegação `Navigator.pop`).
- **Marcar como concluída:** `store.toggleCompleted(task)` → `repository.setCompleted()`
  → cancela o lembrete (ou reagenda se reaberta com vencimento futuro) → `load()` —
  o item risca na hora.
- **Filtros:** `setFilter()`/`setCategoryFilter()` apenas atualizam o estado e
  notificam; o getter `tasks` aplica `_filtered` (composição de filtros de status
  e categoria) — a lista filtra sem tocar no banco.

Padrão reconhecível: **MVVM + unidirecional (dados → estado → UI)**, sem bibliotecas
de estado externas além do provider.

---

## 3. SQLite Persistence

- **Criação do banco:** `TodoDatabase._open()` — `getDatabasesPath()` + `openDatabase(
  p.join(dir, 'todo.db'), version: 1, ...)`; arquivo `todo.db` no armazenamento
  interno do app.
- **Integridade referencial:** `onConfigure` executa `PRAGMA foreign_keys = ON` — o
  sqflite **não** habilita FK por padrão; sem isso o `ON DELETE SET NULL` nunca
  dispararia (bug real encontrado pela verificação independente e corrigido na
  Entrada 04 do BUILD_LOG).
- **Schema:** `Category (id, name, color)` e `Task (id, title, description, completed,
  dueDateTime, createdAt, categoryId)` com FK `categoryId → Category(id) ON DELETE
  SET NULL` e índice `idx_task_category`. Sem categorias iniciais (o usuário cria
  pela UI).
- **CRUD:** todo em `TodoDatabase` (SQL nomeado por método) — `allTasks` (ordenado
  por `completed ASC, dueDateTime IS NULL, dueDateTime ASC, createdAt DESC` —
  pendências primeiro, vencidas antes, recentes depois), `taskById`, `insertTask`,
  `updateTask`, `setCompleted`, `deleteTask`; `allCategories` (`COLLATE NOCASE`),
  `categoryById`, `insertCategory`, `updateCategory`, `deleteCategory`.
- **Detalhe do INSERT:** `insertTask(task)` grava `task.toMap()..remove('id')` —
  remove o id para o AUTOINCREMENT do SQLite gerar o próximo (o modelo usa
  `id: 0` como placeholder na criação).

---

## 4. Follow One Operation

Rastreando a criação de uma nova tarefa:

1. Usuário toca **"Nova tarefa"** (FAB) → `openTaskEditor(context, store)` em
   `ui/app.dart` → `Navigator.push(TaskEditorScreen(taskId: null))`;
2. `initState` → `_loadExisting()` (taskId null: apenas marca `_loaded`) — o form
   começa vazio;
3. Usuário digita título/descrição, escolhe categoria (dropdown) e vencimento
   (`showDatePicker` + `showTimePicker` nativos) → toca **Salvar** → `_save()`:
   - valida o form (`Form` + `validator`: título vazio → "Informe um título" e não salva);
   - chama `store.saveTask(id: null, ...)` → `repository.insertTask(Task(id: 0, ...))`
     → `db.insert('Task', toMap()..remove('id'))` → **INSERT na tabela Task do SQLite**
     com AUTOINCREMENT;
   - se vencimento futuro e notificações disponíveis (`_notifier.isAvailable`):
     `notifier.schedule(taskId, título, descrição, due)` → `zonedSchedule` com
     `AndroidScheduleMode.exactAllowWhileIdle` e id `100000 + taskId`;
   - `await load()` → recarrega do banco → `notifyListeners()`;
4. `Navigator.pop()` volta à lista → `ListenableBuilder` reconstrói com o `tasks`
   recém-carregado → **a tarefa aparece na lista automaticamente**.

---

## 5. Navigation

- **Imperativa** (`Navigator.push`/`Navigator.pop`), sem biblioteca de navegação:
  helpers `openTaskEditor(context, store, {taskId})` e `openCategories(context, store)`
  em `ui/app.dart`.
- **Lista → editor:** `openTaskEditor` com `taskId` null (nova) ou preenchido (editar).
- **Dados passados:** apenas o **task ID** (`int?`). O editor busca o objeto completo
  do banco via `store.repositoryTaskById(id)`. Categorias são carregadas pelo próprio
  store (compartilhado) — o dropdown lê `store.categories`.
- **Sair do app:** "Sair" na AppBar → diálogo de confirmação → `SystemNavigator.pop()`
  encerra a atividade (voltando ao launcher).

---

## 6. Notifications

Implementadas em `lib/todo_notifier.dart` (flutter_local_notifications + timezone,
canal "Lembretes de tarefas" / `task_reminders`):

- **Agendamento:** `schedule(taskId, title, body, due)` chama `zonedSchedule` com
  `tz.TZDateTime.from(due, tz.local)` e `AndroidScheduleMode.exactAllowWhileIdle`
  (alarme exato). O vínculo notificação ↔ tarefa é o id derivado
  `notificationIdFor(taskId) = 100000 + taskId` — sem tabela de mapeamento,
  cancelamento e reagendamento determinísticos.
- **Permissão:** API 33+ exige `POST_NOTIFICATIONS` — `requestPermission()` chama
  `requestNotificationsPermission()` no boot do app (`main.dart`); `isAvailable`
  checa antes de agendar (nunca crasha se negada).
- **Mudança de vencimento:** `saveTask` cancela o lembrete antigo se a data mudou
  e reagenda se futura (`zonedSchedule` sobrescreve).
- **Concluída:** `toggleCompleted` cancela o lembrete; ao reabrir, reagenda se o
  vencimento ainda é futuro.
- **Excluída:** `deleteTask` cancela o lembrete antes de remover a tarefa.
- **Timezone:** `init()` inicializa o tzdata e tenta fixar `America/Sao_Paulo`
  como local (fallback silencioso para o fuso do dispositivo).

---

## 7. Agent Decisions

Decisões importantes feitas pelo agente que **não** foram especificadas no assignment:

1. **Flutter + alvo apenas Android** — o assignment pedia "app mobile"; linguagem e
   estrutura eram livres. iOS descartado (Linux sem Xcode), web/desktop sem uso.
2. **sqflite direto (sem ORM)** — alternativa considerada: drift (geração de código)
   e floor; descartados por peso desnecessário para um schema de 2 tabelas.
3. **Estado em ChangeNotifier (provider) com refresh determinístico (`load()` após
   toda escrita)** — a UI sempre relê do banco; evita a classe de bugs que o KMP
   enfrentou com invalidação automática pouco confiável.
4. **IDs de notificação derivados da tarefa** (`100000 + taskId`) — cancelamento e
   reagendamento determinísticos sem tabela extra.
5. **Navegação imperativa com helpers** em vez de biblioteca (go_router etc.) —
   escopo pequeno, 3 telas.
6. **Date/Time pickers nativos do Material** (`showDatePicker`/`showTimePicker`) —
   o Flutter os tem prontos, diferente do Compose MP 1.6 usado no KMP.
7. **Paleta de cores para categorias** — novas categorias recebem a primeira cor
   livre de uma paleta de 10 cores Material (`categoryColors` em
   `todo_repository.dart`), em vez de cor única fixa.
8. **Filtros em `ChoiceChip`s horizontais** (status + categoria) — mesmo problema
   de overflow resolvido com FlowRow no KMP; aqui `SingleChildScrollView` horizontal.
9. **Sem categorias iniciais no schema** — o KMP semeava 3 categorias; no Flutter
   o banco nasce vazio e o usuário cria pela UI (mais fiel ao fluxo real de uso).
10. **Política de exclusão de categoria = ON DELETE SET NULL** — as tarefas ficam
    sem categoria (com `PRAGMA foreign_keys = ON` para o SQLite realmente aplicar).

### Modelos de IA utilizados

O desenvolvimento deste app foi conduzido por agentes de IA executando no servidor
(via OpenClaude), com os seguintes modelos. Contagem de chamadas atribuída por
diretório de trabalho nos logs JSONL das sessões — sessão de 2026-09-26 (fase
Flutter; a mesma sessão também encerrou o KMP):

| Modelo | Chamadas (todo-flutter) | Chamadas (raiz, coordenação) | Papel |
|---|---|---|---|
| `z-ai/glm-5.3-flash` | 373 | 52 | Modelo principal (modo fast) — implementação, builds, testes e validação no emulador |
| `z-ai/glm-5.3` | 24 | 7 | Modelo alternativo — iterações de código e correções |
| `moonshotai/kimi-k3` | 0 | 0 | Não usado nesta fase |

Para referência, na mesma sessão de 26/09 o encerramento do KMP consumiu:
`z-ai/glm-5.3` 268 + `z-ai/glm-5.3-flash` 90 + `moonshotai/kimi-k3` 51 (diretório
todo-kmp). Todos os modelos operaram sobre o mesmo ambiente e histórico; a
orquestração (sessão, ferramentas e permissões) ficou a cargo do OpenClaude no
servidor.

---

## 8. BUILD_LOG Analysis

Exemplos de `BUILD_LOG.md` (Entradas 01–04):

- **Problema (Entrada 03):** o build do APK falhou em cascata — JDK sem `jlink`
  (só JRE instalado), AGP 8.1.0 gerando módulo Android malformado com o jlink do
  JDK 21 ("platformString missing delimiter"), e core library desugaring exigido
  pelo plugin de notificações.
- **Como tentou resolver:** correções incrementais — instalar
  `openjdk-21-jdk-headless`, depois atualizar wrapper (Gradle 8.3 → 8.7 + AGP
  8.1.0 → 8.3.2, combinação já validada no todo-kmp), depois habilitar
  `coreLibraryDesugaring` com `desugar_jdk_libs:2.1.4` (a versão 2.0.4 falhou antes).
- **Primeira solução funcionou?** Não — cada correção revelava o erro seguinte.
  `✓ Built app-debug.apk` após 3 iterações.
- **Problema (Entrada 04):** divergências contra o PROMPT.md encontradas pelo
  usuário após validar a versão funcional — filtros de status/categoria não
  expostos na UI, sem opção de sair, FABs sem título, descrições não mostradas;
  a verificação independente encontrou ainda o bug do `PRAGMA foreign_keys`.
- **O que foi feito no fim:** correções aplicadas de uma vez, rebuild e validação
  por screenshots no emulador (filtros funcionais, descrição na lista, sair para
  o launcher, FK SET NULL validado).

**O que o build log ajudou a entender:** o **processo** — que o caminho até o
build funcional foi iterativo (ambiente: JDK → AGP/Gradle → desugaring), que as
correções de UI vieram de validação real no emulador (o código "compilava e
rodava" mas não atendia a spec), e que o bug do FK pragma era invisível no uso
normal (só aparecia ao excluir categoria em uso). Olhando só o código final,
nada disso é visível — o log explica o **porquê** de padrões não óbvios (ex.: o
`onConfigure` com `PRAGMA foreign_keys = ON` só faz sentido sabendo que o sqflite
não habilita FK por padrão).

---

## Como compilar e rodar

```bash
# Rebuild (APK debug) + instalação no emulador
export PATH="$HOME/development/flutter/bin:$PATH"
cd ~/repositories_git/Desenvolvimento/todo-flutter
flutter build apk --debug
$HOME/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk
$HOME/Android/Sdk/platform-tools/adb shell am start -n com.example.to_do_flutter/.MainActivity

# Desenvolvimento iterativo (hot reload — mudanças .dart a quente)
flutter run   # r = hot reload, R = hot restart, q = sair

# Testes e análise
flutter test
flutter analyze
```

## Limitações conhecidas

- iOS não é suportado neste ambiente (Linux sem Xcode); o projeto foi gerado
  apenas para Android.
- Notificações exigem a janela do emulador aberta (com `-no-window` não as exibe
  visualmente).
- Widget tests com sqflite não rodam sem method channel — a cobertura de testes
  é unitária (modelos/paleta/IDs), não de tela.
