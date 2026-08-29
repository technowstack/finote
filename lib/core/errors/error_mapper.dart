String mapErrorToMessage(Object error) => switch (error) {
  FormatException() || ArgumentError() => 'Data yang dimasukkan tidak valid.',
  _ => 'Terjadi kesalahan. Silakan coba lagi.',
};
