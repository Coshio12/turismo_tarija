import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/hotel_provider.dart';
import '../../../core/models/message_model.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov  = context.watch<HotelProvider>();
    final hotel = context.watch<AuthProvider>().user!;
    final unread = prov.unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Buzón de mensajes',
                style: TextStyle(fontSize: 17)),
            if (unread > 0)
              Text(
                '$unread mensaje${unread == 1 ? '' : 's'} sin leer',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (unread > 0)
            IconButton(
              tooltip: 'Marcar todo como leído',
              icon: const Icon(Icons.done_all),
              onPressed: () => _markAllRead(context, prov, hotel.uid),
            ),
        ],
      ),
      body: prov.inbox.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No tienes mensajes',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prov.inbox.length,
              itemBuilder: (_, i) {
                final msg = prov.inbox[i];
                return _MessageCard(
                  message: msg,
                  onOpen: () {
                    // Marcar como leído antes de abrir
                    // (actualización optimista en provider → badge baja al instante)
                    if (!msg.isRead) {
                      prov.markRead(hotel.uid, msg.messageId);
                    }
                    _showMessage(context, msg);
                  },
                );
              },
            ),
    );
  }

  void _markAllRead(
      BuildContext context, HotelProvider prov, String hotelId) {
    final unreadMsgs =
        prov.inbox.where((m) => !m.isRead).toList();
    for (final msg in unreadMsgs) {
      prov.markRead(hotelId, msg.messageId);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todos los mensajes marcados como leídos'),
        backgroundColor: Color(0xFF1A5276),
      ),
    );
  }

  void _showMessage(BuildContext context, MessageModel msg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A5276).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings,
                      color: Color(0xFF1A5276), size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Mensaje del administrador',
                    style: TextStyle(color: Colors.grey)),
              ]),
              const SizedBox(height: 16),
              Text(
                msg.subject,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(msg.createdAt),
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12),
              ),
              const Divider(height: 28),
              Text(msg.body,
                  style: const TextStyle(height: 1.7, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Message Card ──────────────────────────────────────────────────────
class _MessageCard extends StatelessWidget {
  final MessageModel message;
  final VoidCallback onOpen;
  const _MessageCard({required this.message, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isUnread = !message.isRead;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFEAF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? const Color(0xFF1A5276).withOpacity(0.3)
              : Colors.grey.shade200,
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: const Color(0xFF1A5276).withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isUnread
                ? const Color(0xFF1A5276).withOpacity(0.12)
                : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isUnread ? Icons.mark_email_unread : Icons.mark_email_read,
            color: isUnread
                ? const Color(0xFF1A5276)
                : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          message.subject,
          style: TextStyle(
            fontWeight:
                isUnread ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            DateFormat('dd/MM/yyyy · HH:mm').format(message.createdAt),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        trailing: isUnread
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Nuevo',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right,
                color: Colors.grey, size: 20),
        onTap: onOpen,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}