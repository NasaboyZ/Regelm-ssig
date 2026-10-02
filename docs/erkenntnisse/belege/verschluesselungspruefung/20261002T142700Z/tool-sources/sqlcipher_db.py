"""Minimal local SQLCipher adapter; no dependency on Python's plain sqlite3."""
import ctypes as c
from pathlib import Path

LIBRARY = Path(__file__).resolve().parent / 'vendor/libsqlcipher.dylib'
lib = c.CDLL(str(LIBRARY))


def api(name, result, *args):
    fn = getattr(lib, name)
    fn.restype, fn.argtypes = result, list(args)
    return fn


ptr = c.c_void_p
open_db = api('sqlite3_open_v2', c.c_int, c.c_char_p, c.POINTER(ptr), c.c_int, c.c_char_p)
close_db = api('sqlite3_close', c.c_int, ptr)
prepare = api('sqlite3_prepare_v2', c.c_int, ptr, c.c_char_p, c.c_int, c.POINTER(ptr), c.POINTER(c.c_char_p))
step = api('sqlite3_step', c.c_int, ptr)
finalize = api('sqlite3_finalize', c.c_int, ptr)
errmsg = api('sqlite3_errmsg', c.c_char_p, ptr)
bind_text = api('sqlite3_bind_text', c.c_int, ptr, c.c_int, c.c_char_p, c.c_int, ptr)
bind_blob = api('sqlite3_bind_blob', c.c_int, ptr, c.c_int, ptr, c.c_int, ptr)
bind_int = api('sqlite3_bind_int64', c.c_int, ptr, c.c_int, c.c_int64)
col_count = api('sqlite3_column_count', c.c_int, ptr)
col_type = api('sqlite3_column_type', c.c_int, ptr, c.c_int)
col_int = api('sqlite3_column_int64', c.c_int64, ptr, c.c_int)
col_blob = api('sqlite3_column_blob', ptr, ptr, c.c_int)
col_text = api('sqlite3_column_text', ptr, ptr, c.c_int)
col_bytes = api('sqlite3_column_bytes', c.c_int, ptr, c.c_int)


class DatabaseError(RuntimeError):
    pass


class Database:
    def __init__(self, path, key=None, *, readonly=False):
        self.handle = ptr()
        code = open_db(str(path).encode(), c.byref(self.handle), 1 if readonly else 6, None)
        if code:
            message = errmsg(self.handle).decode()
            self.close()
            raise DatabaseError(message)
        try:
            if key is not None:
                # Only locally defined fixture keys reach this configuration path.
                self.query("PRAGMA key = '" + key.replace("'", "''") + "'")
            self.query('PRAGMA temp_store = MEMORY')
            self.query('PRAGMA secure_delete = ON')
        except BaseException:
            self.close()
            raise

    def query(self, sql, params=()):
        statement, tail = ptr(), c.c_char_p()
        code = prepare(self.handle, sql.encode(), -1, c.byref(statement), c.byref(tail))
        if code:
            raise DatabaseError(errmsg(self.handle).decode())
        try:
            if not statement:
                raise DatabaseError('Empty statement')
            if tail.value and tail.value.strip():
                raise DatabaseError('Only one statement is allowed')
            for index, value in enumerate(params, 1):
                if isinstance(value, int):
                    code = bind_int(statement, index, value)
                elif isinstance(value, bytes):
                    code = bind_blob(statement, index, value, len(value), ptr(-1))
                else:
                    raw = str(value).encode()
                    code = bind_text(statement, index, raw, len(raw), ptr(-1))
                if code:
                    raise DatabaseError(errmsg(self.handle).decode())
            rows = []
            while (code := step(statement)) == 100:
                row = []
                for index in range(col_count(statement)):
                    kind = col_type(statement, index)
                    if kind == 1:
                        value = col_int(statement, index)
                    elif kind == 5:
                        value = None
                    else:
                        address = col_blob(statement, index) if kind == 4 else col_text(statement, index)
                        raw = c.string_at(address, col_bytes(statement, index))
                        value = raw if kind == 4 else raw.decode('utf-8', errors='replace')
                    row.append(value)
                rows.append(row)
            if code != 101:
                raise DatabaseError(errmsg(self.handle).decode())
            return rows
        finally:
            finalize(statement)

    def close(self):
        if self.handle:
            code = close_db(self.handle)
            if code:
                raise DatabaseError('Could not close SQLCipher connection')
            self.handle = ptr()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()
