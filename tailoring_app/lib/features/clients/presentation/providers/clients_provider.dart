import 'package:flutter/foundation.dart';

import '../../data/clients_repository.dart';
import '../../domain/client.dart';

/// Paginated, searchable client list. The 300ms debounce lives in the
/// screen; this provider guards against out-of-order responses so a slow
/// early request can never overwrite a newer search's results.
class ClientsProvider extends ChangeNotifier {
  ClientsProvider({ClientsRepository? repository})
      : _repo = repository ?? ClientsRepository();

  static const int _pageSize = 20;

  final ClientsRepository _repo;
  final List<Client> items = <Client>[];

  bool loading = false;
  bool hasMore = true;
  String? error;
  String _search = '';
  int _requestSeq = 0;

  Future<void> refresh({String? search}) async {
    _search = search ?? _search;
    final int seq = ++_requestSeq;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final List<Client> page =
          await _repo.list(search: _search, limit: _pageSize, offset: 0);
      if (seq != _requestSeq) return; // stale response — drop it
      items
        ..clear()
        ..addAll(page);
      hasMore = page.length == _pageSize;
    } catch (e) {
      if (seq != _requestSeq) return;
      error = e.toString();
    } finally {
      if (seq == _requestSeq) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    final int seq = _requestSeq;
    loading = true;
    notifyListeners();
    try {
      final List<Client> page = await _repo.list(
          search: _search, limit: _pageSize, offset: items.length);
      if (seq != _requestSeq) return;
      items.addAll(page);
      hasMore = page.length == _pageSize;
    } catch (e) {
      if (seq == _requestSeq) error = e.toString();
    } finally {
      if (seq == _requestSeq) {
        loading = false;
        notifyListeners();
      }
    }
  }
}
