# BUILD_LOG.md — to_do_flutter

Histórico de desenvolvimento do app To-Do em Flutter (fase 2 da atividade).
Pai: `Desenvolvimento/`. Irmão: `todo-kmp/` (fase 1, concluído).

Formato de entrada conforme a especificação (PROMPT.md #1): Prompt / Request,
Decision Summary, Actions Performed, Result, Problems / Errors, Fixes Attempted,
Current Status. Arquivo **append-only**: entradas antigas não são reescritas.

---

## Entrada 01 — 2026-09-25

### Prompt / Request

Usuário (contexto): KMP concluído e validado ("ficou bom e comitei"); para encerrar a
atividade KMP e começar a fase Flutter, finalizar BUILD_LOG.md/README.md do KMP e
iniciar o to-do_flutter. Primeiro passo desta fase: instalar o Flutter SDK
(adiado na fase 1 conforme memória do projeto).

### Decision Summary

- **Flutter SDK 3.24.5 stable (Linux)** baixado de
  `storage.googleapis.com/flutter_infra_release/releases` e extraído em
  `~/development/flutter` — local fora do repositório, padrão da documentação
  Flutter; evita inflar o repo com os ~662 MB do SDK.
- Alternativa considerada: snap (`snap install flutter`) — descartada por depender
  de sudo/pacote gerenciado fora do controle do usuário; tarball é o caminho
  recomendado pela doc oficial.

### Actions Performed

- Download do tarball `flutter_linux_3.24.5-stable.tar.xz` (662 MB) para
  `~/development/`.
- Extração para `~/development/flutter` (em andamento nesta entrada).

### Result

Download OK; extração em andamento. `flutter doctor` será executado na próxima
entrada para validar o ambiente (JDK 21 e Android SDK já presentes).

### Problems / Errors

— (nenhum até o momento)

### Fixes Attempted

— (não aplicável)

### Current Status

Needs testing

---

## Entrada 02 — 2026-09-25

### Prompt / Request

Continuação: após `flutter doctor` validado (Flutter ✓, Android toolchain ✓,
emulador ✓; Linux desktop ✗ — clang/cmake/ninja ausentes, irrelevante para o
alvo Android), criar o projeto Flutter em `todo-flutter/`.

### Decision Summary

- **`flutter create --org com.example --project-name to_do_flutter --platforms android .`**
  dentro do diretório existente (que já tinha `.git` e `README.md` da fase 1) — o
  comando popula o diretório sem sobrescrever arquivos fora do escopo.
- Apenas **Android** como plataforma: o alvo da atividade é o emulador Android;
  iOS/web/desktop ficariam sem uso.
- Baseline: `flutter build apk --debug` antes de qualquer código próprio, para
  isolar problemas de ambiente dos problemas de código.
- `gradle-wrapper.properties` veio com **Gradle 8.3** + **AGP 8.1.0**; JDK 21 é
  suportado pelo Gradle a partir do 8.5 — se o baseline falhar com erro de
  toolchain, atualizar wrapper para 8.7 + AGP 8.3.x (combinação já validada no
  todo-kmp).

### Actions Performed

- Projeto criado: `lib/main.dart`, `pubspec.yaml`, `android/` (app, gradle,
  gradle wrapper 8.3), `test/`, `analysis_options.yaml`.
- `flutter build apk --debug` executado em background (primeiro build baixa
  dependências).

### Result

Projeto criado com sucesso. Build baseline em andamento.

### Problems / Errors

- Aviso do Gradle sobre compatibilidade Java/Gradle exibido durante o `flutter
  create` (Gradle 8.3 vs JDK 21) — potencial falha no build, monitorando.

### Fixes Attempted

— (nenhum ainda; plano de contingência: wrapper 8.7 + AGP 8.3.x)

### Current Status

In progress

> **Atualização Entrada 02:** build baseline concluído com sucesso
> (`flutter build apk --debug` — 333.8s, APK em
> `build/app/outputs/flutter-apk/app-debug.apk`). Gradle 8.3 + AGP 8.1.0 +
> JDK 21 funcionaram — o aviso de compatibilidade era apenas warning, sem
> falha. Status: **Completed**.

---

## Entrada 03 — 2026-09-26

### Prompt / Request

Continuação: implementar o app To-Do em Flutter conforme PROMPT.md (SQLite,
categorias, notificações locais, telas de lista/editor/categorias) e buildar
para verificação.

### Decision Summary

- **Arquitetura MVVM-like com ChangeNotifier (provider):** `TodoStore`
  centraliza estado (tasks, categories, filtros) e expõe operações; telas
  escutam via `ListenableBuilder`. Total escrita → `notifyListeners()` → telas
  recarregam do banco (mesma filosofia de refresh determinístico do KMP).
- **SQLite direto (sqflite, sem ORM):** `TodoDatabase` com SQL nomeado e
  `TodoRepository` como camada de regras (paleta de cores, IDs de notificação).
- **Notificações:** `flutter_local_notifications` 19.5.0 + `timezone`;
  `TodoNotifier` encapsula init/permissão/schedule/cancel.
- **Navegação imperativa** (`Navigator.push`) em `ui/app.dart`; editor recebe
  apenas o `taskId` e recarrega o objeto do banco.
- **IDs de notificação derivados da tarefa** (`notificationIdFor(taskId) =
  100000 + taskId`) — cancelamento/schedule determinísticos, sem tabela extra.
- **CategoryDropdown** no editor (em vez de chips) — evita overflow, mesmo
  problema corrigido no KMP.
- **showDatePicker/showTimePicker nativos** — o Flutter tem pickers prontos,
  diferente do Compose MP 1.6.

### Actions Performed

- Dependências adicionadas via `flutter pub add`: sqflite, path, provider,
  intl, flutter_local_notifications, timezone, flutter_timezone.
- Arquivos criados: `lib/models.dart`, `lib/todo_database.dart`,
  `lib/todo_repository.dart`, `lib/todo_notifier.dart`, `lib/todo_store.dart`,
  `lib/main.dart`, `lib/ui/app.dart`, `lib/ui/task_list_screen.dart`,
  `lib/ui/task_editor_screen.dart`, `lib/ui/categories_screen.dart`,
  `lib/ui/category_dropdown.dart`.
- AndroidManifest: POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED,
  SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM.
- `test/models_test.dart` (6 testes unitários de modelos/paleta).

### Result

- `flutter analyze`: No issues found.
- `flutter test`: 6/6 passando.
- `flutter build apk --debug` executado (resultado na próxima entrada).

### Problems / Errors

1. **Colisão de nomes `Category`:** o analyzer reclamou de conflito entre a
   anotação `Category` do `package:flutter/foundation.dart` e o modelo
   próprio. Resolvido com `hide Category` no import do store e extensão
   `CategoryCopy` em `todo_repository.dart`.
2. **API do plugin 19.5.0 mudou:** `initialize(settings)` é posicional (não
   `settings:`) e `uiLocalNotificationDateInterpretation` foi removido do
   `zonedSchedule`. Corrigido consultando o código-fonte do plugin no
   .pub-cache.
3. **`pumpAndSettle` trava em widget test:** sqflite não roda no ambiente de
   teste (sem method channel); teste de fumaça substituído por testes
   unitários puros (`test/models_test.dart`).

### Fixes Attempted

- Fixes 1–3 acima aplicados e validados com analyze/test.

### Current Status

In progress (build do APK em andamento)
