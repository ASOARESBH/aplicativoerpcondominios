# ERP Condomínios — Portal do Morador (App Flutter)

Aplicativo móvel do **ERP Condomínios** para Android e iOS, desenvolvido em Flutter com arquitetura Clean Architecture + MVVM.

## Funcionalidades

| Módulo | Descrição |
|---|---|
| **Autenticação** | Login com CPF/senha, biometria (Face ID / Touch ID), recuperação de senha |
| **Multi-Tenant** | Suporte a múltiplos condomínios via URL dinâmica |
| **Perfil** | Dados cadastrais, atualização de contatos, troca de senha |
| **Visitantes** | Cadastro e gestão de visitantes autorizados |
| **Acessos (QR Code)** | Geração de QR Code para entrada de visitantes |
| **Hidrômetro** | Leituras, consumo e gráfico histórico |
| **Dependentes** | Cadastro de moradores dependentes |
| **Protocolos** | Correspondências e encomendas |
| **Veículos** | Listagem de veículos cadastrados |
| **Documentos** | Acesso ao GED (Gestão Eletrônica de Documentos) |
| **Projetos** | Acompanhamento de obras com linha do tempo |
| **Chamados (OS)** | Abertura e acompanhamento de chamados |
| **Marketplace** | Vitrine de serviços e produtos do condomínio |
| **Notificações** | Push notifications via Firebase Cloud Messaging |

## Requisitos

- Flutter 3.32.4+
- Dart 3.x
- Android SDK 21+ (Android 5.0+)
- iOS 13.0+

## Configuração

### 1. Clonar o repositório

```bash
git clone https://github.com/ASOARESBH/aplicativoerpcondominios.git
cd aplicativoerpcondominios
flutter pub get
```

### 2. Configurar Firebase (Push Notifications)

**Android:**
1. Criar projeto no Firebase Console
2. Adicionar app Android com package `br.com.erpcondominios`
3. Baixar `google-services.json` e colocar em `android/app/`

**iOS:**
1. Adicionar app iOS com bundle ID `br.com.erpcondominios`
2. Baixar `GoogleService-Info.plist` e colocar em `ios/Runner/`

### 3. Build Android

```bash
# Release APK
flutter build apk --release

# Release AAB (Google Play Store)
flutter build appbundle --release
```

### 4. Build iOS

```bash
# Requer macOS com Xcode
flutter build ios --release
```

## Arquitetura

```
lib/
├── core/          # Utilitários, tema, constantes, segurança
├── domain/        # Regras de negócio puras (entities, repositories)
├── data/          # Implementação de dados (datasources, models)
└── presentation/  # UI e estado (providers, router, screens, widgets)
```

## Versão

**v1.0.0** | Flutter 3.32.4 | Dart 3.x
