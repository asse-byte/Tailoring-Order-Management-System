import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';

class ModelMedia {
  final String id;
  final String url;
  final String kind; // 'image' | 'video'
  final String? thumbUrl;

  const ModelMedia({
    required this.id,
    required this.url,
    required this.kind,
    this.thumbUrl,
  });

  factory ModelMedia.fromJson(Map<String, dynamic> json) {
    return ModelMedia(
      id: json['id'] as String,
      url: json['url'] as String,
      kind: json['kind'] as String,
      thumbUrl: json['thumb_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'kind': kind,
        'thumb_url': thumbUrl,
      };
}

class PretAPorterModel {
  final String id;
  final String name;
  final String fabricType;
  final double price;
  final String? description;
  final List<ModelMedia> media;

  const PretAPorterModel({
    required this.id,
    required this.name,
    required this.fabricType,
    required this.price,
    this.description,
    required this.media,
  });

  factory PretAPorterModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> mediaJson = json['media'] as List<dynamic>? ?? [];
    return PretAPorterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      fabricType: json['fabric_type'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String?,
      media: mediaJson.map((e) => ModelMedia.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'fabric_type': fabricType,
        'price': price,
        'description': description,
        'media': media.map((e) => e.toJson()).toList(),
      };
}

class PretAPorterRepository {
  PretAPorterRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<PretAPorterModel>> list({
    int limit = 20,
    int offset = 0,
  }) async {
    final dynamic res = await _api.get('/api/pret-a-porter', query: {
      'limit': '$limit',
      'offset': '$offset',
    });
    return (res['items'] as List)
        .map((e) => PretAPorterModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PretAPorterModel> create({
    required String name,
    required String fabricType,
    required double price,
    String? description,
    required List<Map<String, String>> media,
  }) async {
    final dynamic res = await _api.post('/api/pret-a-porter', body: {
      'name': name,
      'fabric_type': fabricType,
      'price': price.toInt(),
      'description': description,
      'media': media,
    });
    return PretAPorterModel.fromJson(res as Map<String, dynamic>);
  }

  Future<PretAPorterModel> update(
    String id, {
    required String name,
    required String fabricType,
    required double price,
    String? description,
    required List<Map<String, String>> media,
  }) async {
    final dynamic res = await _api.put('/api/pret-a-porter/$id', body: {
      'name': name,
      'fabric_type': fabricType,
      'price': price.toInt(),
      'description': description,
      'media': media,
    });
    return PretAPorterModel.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _api.delete('/api/pret-a-porter/$id');

  /// Sells a model from the counter
  Future<void> sellModel({
    required String modelId,
    required int quantity,
  }) async {
    await _api.post('/api/sales', body: {
      'kind': 'pret_a_porter', // valeur API exacte — 'pret-a-porter' est rejeté
      'item_id': modelId,
      'qty': quantity,
    });
  }

  /// Uploads media (images/videos) to the REST API
  Future<Map<String, String>> uploadMedia(File file) async {
    final String path = '/api/upload';
    final Uri uri = Uri.parse('${ApiClient.baseUrl}$path');
    final String? jwt = await _api.token;
    
    final request = http.MultipartRequest('POST', uri);
    if (jwt != null) {
      request.headers['Authorization'] = 'Bearer $jwt';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    
    final response = await request.send();
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, 'Échec du téléversement du média.');
    }
    
    final responseBody = await response.stream.bytesToString();
    final Map<String, dynamic> decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    return {
      'url': decoded['url'] as String,
      'thumb_url': (decoded['thumb_url'] as String?) ?? '',
    };
  }
}
