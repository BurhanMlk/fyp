const mongoose = require('mongoose');

const SecurityAlertSchema = new mongoose.Schema({
  userId: { type: String },
  userName: String, userEmail: String,
  alertType: { type: String, enum: [
    'fake_document', 'suspicious_upload', 'spam_detected',
    'multiple_fake_requests', 'abuse_detected', 'unusual_activity',
    'fake_donation_claim', 'rapid_actions'
  ]},
  severity: { type: String, enum: ['low', 'medium', 'high', 'critical'], default: 'medium' },
  description: String,
  evidence: mongoose.Schema.Types.Mixed,
  status: { type: String, enum: ['new', 'investigating', 'resolved', 'dismissed'], default: 'new' },
  resolvedBy: String, resolution: String,
  createdAt: { type: Date, default: Date.now },
});
SecurityAlertSchema.index({ userId: 1, createdAt: -1 });
SecurityAlertSchema.index({ status: 1, severity: 1 });
module.exports = mongoose.model('SecurityAlert', SecurityAlertSchema);
