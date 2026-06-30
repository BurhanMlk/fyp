const mongoose = require('mongoose');

const SupportTicketSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  userName: { type: String },
  userEmail: { type: String },
  userRole: { type: String },
  chatSessionId: { type: mongoose.Schema.Types.ObjectId, ref: 'ChatSession' },
  subject: { type: String, required: true },
  description: { type: String },
  priority: { type: String, enum: ['low', 'medium', 'high', 'urgent'], default: 'medium' },
  status: { type: String, enum: ['open', 'in_progress', 'resolved', 'closed'], default: 'open' },
  assignedTo: { type: String },
  conversation: [{
    role: { type: String, enum: ['user', 'admin', 'system'] },
    message: String,
    timestamp: { type: Date, default: Date.now },
  }],
  attachments: [{ type: String }],
  resolution: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('SupportTicket', SupportTicketSchema);
