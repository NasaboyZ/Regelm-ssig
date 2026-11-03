import 'dart:ffi';
import 'dart:io';

typedef GoFreeFunction = void Function(Pointer<Void>);

final class GoNativeLibrary {
  GoNativeLibrary._(this.library)
    : free = library.lookupFunction<_FreeNative, _FreeDart>(
        'regelmaessig_transfer_free',
      );

  final DynamicLibrary library;
  final GoFreeFunction free;

  static GoNativeLibrary? tryLoad() {
    for (final name in _names()) {
      try {
        return GoNativeLibrary._(DynamicLibrary.open(name));
      } on Object {
        // Native Go is optional until the platform artifact is bundled.
      }
    }
    return null;
  }

  static Iterable<String> _names() sync* {
    if (Platform.isAndroid) {
      yield 'libregelmaessig_transfer.so';
    } else if (Platform.isIOS) {
      yield 'regelmaessig_transfer.framework/regelmaessig_transfer';
      yield 'libregelmaessig_transfer.dylib';
    } else if (Platform.isMacOS) {
      yield 'libregelmaessig_transfer.dylib';
    }
  }
}

typedef _FreeNative = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);
