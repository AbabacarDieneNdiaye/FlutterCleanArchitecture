import 'dart:io';

import 'package:clean_architect/features/data/datasource/binding/cache/binding_cache.dart';
import 'package:clean_architect/features/data/datasource/binding/cache/constants.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';

//don't format doc
class LoggingInterceptors extends InterceptorsWrapper {
  final Dio _dio;
  SharedPrefs prefs;

  var logger = Logger();

  LoggingInterceptors(this._dio);

  @override
  Future onRequest(RequestOptions options) async {
    final storageToken = await prefs.getString(Constants.accessToken);

    logger.d(
        "--> ${options.method != null ? options.method.toUpperCase() : 'METHOD'} ${"" + (options.baseUrl ?? "") + (options.path ?? "")}");
    logger.i("Headers:");
    options.headers.forEach((k, v) => print('$k: $v'));
    if (options.queryParameters != null) {
      logger.v("queryParameters:");
      options.queryParameters.forEach((k, v) => print('$k: $v'));
    }
    if (options.data != null) {
      logger.v("Body: ${options.data}");
    }
    logger.i(
        "--> END ${options.method != null ? options.method.toUpperCase() : 'METHOD'}");
    options.headers.addAll({'Authorization': 'Bearer $storageToken'});

    return options;
  }

  @override
  Future onResponse(Response response) {
    logger.v(
        "<-- ${response.statusCode} ${(response.request != null ? (response.request.baseUrl + response.request.path) : 'URL')}");
    logger.i("Headers:");

    response.headers?.forEach((k, v) => print('$k: $v'));
    logger.v("Response: ${response.data}");
    logger.i("<-- END HTTP");
    return super.onResponse(response);
  }

  @override
  Future onError(DioError dioError) async {
    logger.e(
        "<-- ${dioError.message} ${(dioError.response?.request != null ? (dioError.response.request.baseUrl + dioError.response.request.path) : 'URL')}");

    logger.e(
        "${dioError.response != null ? dioError.response.data : 'Unknown Error'}");

    logger.e("<-- End error");

    int responseCode = dioError.response.statusCode;
    final storageToken = await prefs.getString(Constants.accessToken);

    if (storageToken != null && responseCode == 401 && storageToken != null) {
      _dio.interceptors.requestLock.lock();
      _dio.interceptors.responseLock.lock();
      RequestOptions options = dioError.response.request;

      //implementation refresh token
      options.headers['Authorization'] = 'Bearer' + storageToken;

      _dio.interceptors.requestLock.unlock();
      _dio.interceptors.responseLock.unlock();

      return _dio.request(options.path, options: options);
    } else {
      super.onError(dioError);
    }
  }

  bool shouldRetry(DioError err) {
    return err.type == DioErrorType.DEFAULT &&
        err.error != null &&
        err.error is SocketException;
  }
}