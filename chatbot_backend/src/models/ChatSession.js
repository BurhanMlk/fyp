const mongoose = require('mongoose');

const MessageSchema = new mongoose.Schema({
  role: { type: String, enum: ['user', 'assistant', 'system'], required: true },
  content: { type: String, required: true },
  language: { type: String, enum: ['en', 'ur', 'auto'], default: 'auto' },
  attachments: [{ type: String }],
  timestamp: { type: Date, default: Date.now },
  metadata: { type: mongoose.Schema.Types.Mixed },
});

const ChatSessionSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  userRole: { type: String, enum: ['donor', 'recipient', 'admin', 'super_admin'], required: true },
  userName: { type: String },
  userEmail: { type: String },
  title: { type: String, default: 'New Chat' },
  messages: [MessageSchema],
  context: {
    lastIntent: String,
    currentStep: String,
    pendingAction: String,
    collectedData: mongoose.Schema.Types.Mixed,
  },
  status: { type: String, enum: ['active', 'resolved', 'archived'], default: 'active' },
  supportTicketId: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

ChatSessionSchema.index({ userId: 1, updatedAt: -1 });
ChatSessionSchema.index({ status: 1 });
ChatSessionSchema.index({ 'messages.timestamp': 1 });

module.exports = mongoose.model('ChatSession', ChatSessionSchema);
