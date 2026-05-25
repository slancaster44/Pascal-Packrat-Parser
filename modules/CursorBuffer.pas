unit CursorBuffer;
interface uses Str32;

type
  pChar = ^char; 
  ppChar = ^pChar;

  BufferKind = (BUFFER_DISK, BUFFER_MEMORY);
  BufferMode = (BUFFER_MODE_READ, BUFFER_MODE_WRITE);

  rCursorBuffer = record
    mode : BufferMode;
    case kind : BufferKind of
      BUFFER_DISK : (handle : file of char);
      BUFFER_MEMORY : (cursor, length : cardinal; content : ppChar);
  end;
  pCursorBuffer = ^rCursorBuffer;

procedure DiskCursorBuffer(cb : pCursorBuffer; fname : acRawStr; bm : BufferMode);
procedure MemoryCursorBuffer(
  cb : pCursorBuffer; mem : ppChar; length : cardinal; mode : BufferMode);
function CursorBufferRead(cb : pCursorBuffer) : char;
procedure CursorBufferWrite(cb : pCursorBuffer; c : char);
procedure CursorBufferSeek(cb : pCursorBuffer; pos : cardinal);
function CursorBufferPosition(cb : pCursorBuffer) : cardinal;
function CursorBufferLength(cb : pCursorBuffer) : cardinal;
function CursorBufferEnd(cb : pCursorBuffer) : boolean;
procedure CursorBufferClose(cb : pCursorBuffer);


implementation
uses Assertion, Memory;

procedure DiskCursorBuffer(cb : pCursorBuffer; fname : acRawStr; bm : BufferMode);
begin
  cb^.kind := BUFFER_DISK;
  assign(cb^.handle, @(fname[0]));

  if bm = BUFFER_MODE_WRITE then
    rewrite(cb^.handle)
  else if bm = BUFFER_MODE_READ then
    reset(cb^.handle);

  cb^.mode := bm;
end;

procedure MemoryCursorBuffer(
  cb : pCursorBuffer; mem : ppChar; length : cardinal; mode : BufferMode);
begin
  cb^.kind := BUFFER_MEMORY;
  cb^.cursor := 0;
  cb^.length := length;
  cb^.content := mem;
  cb^.mode := mode;
end;

function CursorBufferRead(cb : pCursorBuffer) : char;
var
  output : char;
begin
  output := char(0);
  MakeAssertion(cb^.mode = BUFFER_MODE_READ, 'Cannot read from non-readable');

  if cb^.kind = BUFFER_DISK then
    read(cb^.handle, output)
  else if (cb^.kind = BUFFER_MEMORY) then
    begin
      MakeAssertion(cb^.cursor < cb^.length, 'Read out of bounds');
      output := (cb^.content^)[cb^.cursor];
      cb^.cursor := cb^.cursor + 1;
    end;

  exit(output);
end;

const
  DEFAULT_MEMBUF_LEN = 32;
procedure CursorBufferWrite(cb : pCursorBuffer; c : char);
var
  newlen, i : cardinal;
  tmp : pChar;
begin
  MakeAssertion(cb^.mode = BUFFER_MODE_WRITE, 'Attempted write to non-writable');

  if cb^.kind = BUFFER_DISK then
    write(cb^.handle, c)
  else
    begin
      if cb^.cursor <= cb^.length then
        begin
          newlen := cb^.length * 2;
          if newlen = 0 then newlen := DEFAULT_MEMBUF_LEN;
          tmp := MemoryAllocate(newlen);

          if cb^.length <> 0 then
            for i := 0 to newlen-1 do
              begin
                tmp[i] := (cb^.content^)[i];
              end;

          cb^.length := newlen;
          cb^.content^ := tmp;
        end;

      (cb^.content^)[cb^.cursor] := c;
      cb^.cursor := cb^.cursor + 1;
    end;
end;

procedure CursorBufferSeek(cb : pCursorBuffer; pos : cardinal);
begin
  if cb^.kind = BUFFER_DISK then
    seek(cb^.handle, pos)
  else
    begin
      MakeAssertion(pos <= cb^.length, 'Seek out of bounds');
      cb^.cursor := pos;
    end;
end;

function CursorBufferPosition(cb : pCursorBuffer) : cardinal;
begin
  if cb^.kind = BUFFER_DISK then
    exit (filepos(cb^.handle))
  else
    exit (cb^.cursor);
end;

function CursorBufferLength(cb : pCursorBuffer) : cardinal;
begin
  if cb^.kind = BUFFER_DISK then
    exit (filesize(cb^.handle))
  else
    exit (cb^.length);
end;

function CursorBufferEnd(cb : pCursorBuffer) : boolean;
begin
  if cb^.kind = BUFFER_DISK then
    exit (eof(cb^.handle))
  else
    exit(cb^.cursor >= cb^.length);
end;

procedure CursorBufferClose(cb : pCursorBuffer);
begin
  if cb^.kind = BUFFER_DISK then close(cb^.handle);
end;

end.