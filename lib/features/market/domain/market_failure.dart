sealed class MarketFailure implements Exception {
  const MarketFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class MarketConfigurationFailure extends MarketFailure {
  const MarketConfigurationFailure(super.message);
}

final class MarketNetworkUnavailable extends MarketFailure {
  const MarketNetworkUnavailable(super.message);
}

final class MarketTimeout extends MarketFailure {
  const MarketTimeout(super.message);
}

final class MarketServerError extends MarketFailure {
  const MarketServerError(super.message, this.statusCode);

  final int statusCode;
}

final class MarketNotFound extends MarketFailure {
  const MarketNotFound(super.message);
}

final class MarketInvalidResponse extends MarketFailure {
  const MarketInvalidResponse(super.message);
}

final class MarketUnsupportedAsset extends MarketFailure {
  const MarketUnsupportedAsset(super.message);
}
