import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';
import '../domain/product.dart';

class ProductsRepository {
  ProductsRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Product>> list({
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    final Map<String, String> query = {
      'limit': '$limit',
      'offset': '$offset',
      if (category != null && category != 'all') 'category': category,
    };
    final dynamic res = await _api.get('/api/products', query: query);
    return (res['items'] as List)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Product> create({
    required String name,
    required String category,
    required double price,
    required int quantity,
    required int lowStockThreshold,
    required List<Map<String, String>> images,
  }) async {
    final dynamic res = await _api.post('/api/products', body: {
      'name': name,
      'category': category,
      'price': price.toInt(),
      'quantity': quantity,
      'low_stock_threshold': lowStockThreshold,
      'images': images,
    });
    return Product.fromJson(res as Map<String, dynamic>);
  }

  Future<Product> update(
    String id, {
    required String name,
    required String category,
    required double price,
    required int quantity,
    required int lowStockThreshold,
    required List<Map<String, String>> images,
  }) async {
    final dynamic res = await _api.put('/api/products/$id', body: {
      'name': name,
      'category': category,
      'price': price.toInt(),
      'quantity': quantity,
      'low_stock_threshold': lowStockThreshold,
      'images': images,
    });
    return Product.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _api.delete('/api/products/$id');

  /// Sells a product from the counter
  Future<void> sellProduct({
    required String productId,
    required int quantity,
  }) async {
    await _api.post('/api/sales', body: {
      'kind': 'produit',
      'item_id': productId,
      'qty': quantity,
    });
  }

  /// Uploads product image using the REST upload API
  Future<Map<String, String>> uploadImage(File file) async {
    // We make a multipart request
    const String path = '/api/upload';
    final Uri uri = Uri.parse('${ApiClient.baseUrl}$path');
    final String? jwt = await _api.token;
    
    final request = HttpMultipartRequestWrapper('POST', uri);
    if (jwt != null) {
      request.headers['Authorization'] = 'Bearer $jwt';
    }
    request.files.add(await MultipartFileWrapper.fromPath('file', file.path));
    
    final response = await request.send();
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, 'Échec du téléversement de l\'image.');
    }
    
    final responseBody = await response.stream.bytesToString();
    final Map<String, dynamic> decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    return {
      'url': decoded['url'] as String,
      'thumb_url': (decoded['thumb_url'] as String?) ?? '',
    };
  }
}



class HttpMultipartRequestWrapper {
  final http.MultipartRequest _request;
  
  HttpMultipartRequestWrapper(String method, Uri url) : _request = http.MultipartRequest(method, url);

  Map<String, String> get headers => _request.headers;
  List<http.MultipartFile> get files => _request.files;

  Future<http.StreamedResponse> send() => _request.send();
}

class MultipartFileWrapper {
  static Future<http.MultipartFile> fromPath(String field, String path) => http.MultipartFile.fromPath(field, path);
}
