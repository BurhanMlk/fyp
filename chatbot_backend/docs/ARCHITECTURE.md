# Blood Bridge AI Chatbot — Architecture

## Folder Structure
```
chatbot_backend/
├── src/
│   ├── config/          # DB connection, env config, constants
│   ├── controllers/     # Request handlers (chat, tickets, admin)
│   ├── middleware/       # Auth, rate-limit, logging, validation
│   ├── models/           # MongoDB schemas
│   │   ├── ChatSession.js
│   │   ├── SupportTicket.js
│   │   └── SecurityAlert.js
│   ├── routes/           # API routes
│   ├── services/         # Business logic
│   │   ├── aiService.js   # LLM integration + intent detection
│   │   ├── documentService.js  # Document analysis
│   │   ├── inventoryService.js # Blood inventory intelligence
│   │   └── notificationService.js  # Push + email
│   ├── utils/            # Language detector, validators, helpers
├── docs/                 # Documentation
└── package.json
```

## Database: MongoDB Collections

| Collection | Purpose |
|-----------|---------|
| chat_sessions | All chat conversations |
| support_tickets | Admin support tickets |
| security_alerts | Suspicious activity logs |
| knowledge_base | FAQ / offline responses |

## API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /api/chat | Send message to AI |
| GET | /api/chat/sessions/:userId | Get user's sessions |
| DELETE | /api/chat/sessions/:id | Delete session |
| POST | /api/chat/voice | Process voice input |
| POST | /api/documents/analyze | Analyze uploaded doc |
| POST | /api/tickets | Create support ticket |
| GET | /api/tickets/:userId | Get user's tickets |
| POST | /api/alerts | Create security alert |
| GET | /api/inventory/status | Get blood inventory |
