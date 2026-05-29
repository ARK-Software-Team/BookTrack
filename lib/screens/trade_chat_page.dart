// lib/screens/trade_chat_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../services/trade_service.dart';

class TradeChatPage extends StatefulWidget {
  final TradeChat chat;
  final String currentUserId;

  const TradeChatPage({
    super.key, required this.chat, required this.currentUserId,
  });

  @override
  State<TradeChatPage> createState() => _TradeChatPageState();
}

class _TradeChatPageState extends State<TradeChatPage> {
  final TradeService _ts = TradeService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String get _myName {
    final auth = Provider.of<AuthService>(context, listen: false);
    return (auth.displayName?.isNotEmpty == true)
        ? auth.displayName!
        : auth.user?.email?.split('@').first ?? 'Ben';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    await _ts.sendMessage(
      chatId: widget.chat.id,
      senderId: widget.currentUserId,
      senderName: _myName,
      text: text,
    );
    _scrollToBottom();
  }

  Future<void> _confirmTrade() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Takas Gerçekleşti mi?'),
        content: const Text(
            'Fiziksel takas gerçekleştiğini onaylıyor musun? '
            'Her iki taraf onayladığında sohbet silinecek ve '
            'takas listesindeki kitaplar kaldırılacak.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Henüz Değil')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Takas Gerçekleşti'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final completed = await _ts.confirmTrade(
      chatId: widget.chat.id, userId: widget.currentUserId,
    );

    if (completed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 Takas tamamlandı! Kitaplar takas listesinden kaldırıldı.'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Onayın alındı. Karşı taraf da onayladığında takas tamamlanacak.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _deleteChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sohbeti Sil'),
        content: const Text(
            'Bu sohbeti silmek istiyor musun?\n\n'
            'Karşı tarafa sohbeti sildiğine dair bildirim gönderilecek. '
            'Karşı taraf da silerse tüm sohbet verisi kalıcı olarak silinir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _ts.deleteChat(
      chatId: widget.chat.id,
      userId: widget.currentUserId,
      userName: _myName,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chat.otherUserDisplayName,
                style: const TextStyle(fontSize: 16)),
            const Text('Takas Sohbeti',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Takas onayla
          StreamBuilder<List<String>>(
            stream: _ts.watchConfirmedBy(widget.chat.id),
            builder: (context, snap) {
              final confirmed = snap.data ?? [];
              final myConfirmed = confirmed.contains(widget.currentUserId);
              return TextButton.icon(
                onPressed: myConfirmed ? null : _confirmTrade,
                icon: Icon(
                  myConfirmed ? Icons.check_circle : Icons.handshake_outlined,
                  size: 18,
                  color: myConfirmed ? Colors.greenAccent : Colors.white,
                ),
                label: Text(
                  myConfirmed
                      ? 'Onaylandı (${confirmed.length}/2)'
                      : 'Takas Oldu',
                  style: TextStyle(
                    color: myConfirmed ? Colors.greenAccent : Colors.white,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
          // Sohbeti sil
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Sohbeti Sil',
            onPressed: _deleteChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Takas detay paneli ────────────────────────────────────
          _TradeDetailBanner(chat: widget.chat, currentUserId: widget.currentUserId),
          // Sohbet alanı
          Expanded(
            child: StreamBuilder<List<TradeMessage>>(
              stream: _ts.watchMessages(widget.chat.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) Navigator.pop(context);
                  });
                  return const SizedBox();
                }
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text(
                          'Takas teklifi kabul edildi!\nAnlaşmak için mesajlaşabilirsiniz.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == widget.currentUserId;
                    final showDate = i == 0 ||
                        messages[i].createdAt.day != messages[i - 1].createdAt.day;

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(_formatDate(msg.createdAt),
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 11)),
                          ),
                        // Sistem mesajı
                        if (msg.isSystem)
                          _SystemMessage(text: msg.text)
                        else
                          _MessageBubble(message: msg, isMe: isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Mesaj gönderme alanı
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8, offset: const Offset(0, -2))
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 42, height: 42,
                      decoration: const BoxDecoration(
                          color: Colors.deepPurple, shape: BoxShape.circle),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Bugün';
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

// ── Sistem mesajı ─────────────────────────────────────────────────────────────

class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

// ── Mesaj balonu ──────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final TradeMessage message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(message.senderName,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey[600],
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
            ],
            Text(message.text,
                style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
            const SizedBox(height: 3),
            Text(
              '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                  fontSize: 9,
                  color: isMe ? Colors.white60 : Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Takas detay banner ────────────────────────────────────────────────────────

class _TradeDetailBanner extends StatelessWidget {
  final TradeChat chat;
  final String currentUserId;

  const _TradeDetailBanner({required this.chat, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final targetTitle = chat.targetBookTitle;
    final offered = chat.offeredListings;

    // Veri yoksa gösterme
    if (targetTitle.isEmpty && offered.isEmpty) return const SizedBox.shrink();

    // targetListingUserId = teklifi ALAN kişi (hedef listing'in sahibi = toUserId)
    // targetListingUserId boşsa (eski doküman): otherUserId'yi targetOwner say
    // çünkü teklifi gönderen (fromUserId) offeredBooks'u veriyor
    final otherUserId = chat.otherUserId;

    String targetOwner = chat.targetListingUserId;
    if (targetOwner.isEmpty) {
      // Fallback: currentUserId'nin karşısındaki kişi targetOwner olsun
      // (hangi yönde olursa olsun en azından bir şey gösterelim)
      targetOwner = otherUserId;
    }

    final isTargetOwner = targetOwner == currentUserId;

    // isTargetOwner == true  → ben teklifi ALAN tarafım
    //   Veriyorsun: targetBook (kendi listelediğim kitap)
    //   Alıyorsun: offeredBooks (karşı tarafın teklif ettiği kitaplar)
    // isTargetOwner == false → ben teklifi GÖNDEREN tarafım
    //   Veriyorsun: offeredBooks (teklif ettiğim kitaplar)
    //   Alıyorsun: targetBook (istediğim kitap)

    final offeredTitles = offered
        .map((l) => l['title'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .toList();

    final List<String> giving = isTargetOwner
        ? (targetTitle.isNotEmpty ? [targetTitle] : [])
        : offeredTitles;

    final List<String> receiving = isTargetOwner
        ? offeredTitles
        : (targetTitle.isNotEmpty ? [targetTitle] : []);

    return Container(
      width: double.infinity,
      color: Colors.deepPurple.withOpacity(0.07),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Veriyorsun
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.arrow_upward, size: 12, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text('Veriyorsun',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500],
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  if (giving.isEmpty)
                    Text('-', style: TextStyle(fontSize: 12, color: Colors.grey[400]))
                  else
                    ...giving.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(t,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const Icon(Icons.swap_horiz, color: Colors.deepPurple, size: 20),
            ),
            // Alıyorsun
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('Alıyorsun',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500],
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_downward, size: 12, color: Colors.green),
                  ]),
                  const SizedBox(height: 4),
                  if (receiving.isEmpty)
                    Text('-', style: TextStyle(fontSize: 12, color: Colors.grey[400]))
                  else
                    ...receiving.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(t,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}