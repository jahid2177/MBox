import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mystreamflix_flutter/services/external_catalog_service.dart';

void main() {
  test('broken Live TV cannot prevent a working movie catalog from loading', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.uri.path.endsWith('/movies.json')) {
        handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200,
          data: <String, dynamic>{
            'Example Movie': <String, dynamic>{
              'year': '2026',
              'links': <Map<String, String>>[
                <String, String>{'url': 'https://media.example.org/movie.mp4'},
              ],
            },
          }));
        return;
      }
      handler.reject(DioException(requestOptions: options,
        response: Response<dynamic>(requestOptions: options, statusCode: 404),
        type: DioExceptionType.badResponse));
    }));
    final service = ExternalCatalogService(client: dio);
    final server = CatalogServer(
      name: 'Test Server', liveTvUrl: 'https://example.org/live.json',
      movies: const [CategorySource('Hollywood', 'https://example.org/movies.json')],
      series: const [], maintenance: false);
    final progress = <int>[];
    final result = await service.load(server,
      onProgress: (items, warnings) => progress.add(items.length));
    expect(result.items, hasLength(1));
    expect(result.items.single.title, 'Example Movie');
    expect(result.problems, contains('Live TV: HTTP 404'));
    expect(progress, contains(1));
  });
}
