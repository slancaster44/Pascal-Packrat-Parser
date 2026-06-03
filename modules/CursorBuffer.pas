unit CursorBuffer;
interface uses Str32;

type
  pChar = ^char; 

  BufferKind = (BUFFER_DISK, BUFFER_MEMORY);
  BufferMode = (BUFFER_MODE_READ, BUFFER_MODE_WRITE);

  rCursorBuffer = record
    mode : BufferMode;
    case kind : BufferKind of
      BUFFER_DISK : (handle : file of char);
      BUFFER_MEMORY : (cursor, length : cardinal; content : pChar);
  end;
  pCursorBuffer = ^rCursorBuffer;

procedure DiskCursorBuffer(cb : pCursorBuffer; fname : acRawStr; bm : BufferMode);
procedure MemoryCursorBuffer(
  cb : pCursorBuffer; mem : pChar; length : cardinal; mode : BufferMode);
function CursorBufferRead(cb : pCursorBuffer) : char;
function CursorBufferReadMultiple
  (cb : pCursorBuffer; bufsize : cardinal) : acRawStr;
procedure CursorBufferWrite(cb : pCursorBuffer; c : char);
procedure WriteHexAscii(cb : pCursorBuffer; c : char);
procedure CursorBufferWriteMultiple(cb : pCursorBuffer; buf : acRawStr);
procedure CursorBufferSeek(cb : pCursorBuffer; pos : cardinal);
function CursorBufferPosition(cb : pCursorBuffer) : cardinal;
function CursorBufferLength(cb : pCursorBuffer) : cardinal;
function CursorBufferEnd(cb : pCursorBuffer) : boolean;
procedure CursorBufferClose(cb : pCursorBuffer);

implementation
uses Assertion;

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
  cb : pCursorBuffer; mem : pChar; length : cardinal; mode : BufferMode);
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
      output := cb^.content[cb^.cursor];
      cb^.cursor := cb^.cursor + 1;
    end;

  exit(output);
end;

function CursorBufferReadMultiple
  (cb : pCursorBuffer; bufsize : cardinal) : acRawStr;
var
  buf : acRawStr;
  i : cardinal;
begin
  MakeAssertion(bufsize <= sizeof(buf), 'Requested size too large for acRawStr');

  if bufsize <> 0 then
    for i := 0 to sizeof(acRawStr)-1 do
      if i < bufsize then 
        buf[i] := CursorBufferRead(cb)
      else
        buf[i] := char(0);
        
  exit (buf);
end;

procedure CursorBufferWrite(cb : pCursorBuffer; c : char);
begin
  MakeAssertion(cb^.mode = BUFFER_MODE_WRITE, 'Attempted write to non-writable');

  if cb^.kind = BUFFER_DISK then
    write(cb^.handle, c)
  else
    begin
      MakeAssertion(cb^.cursor < cb^.length, 'Write out of bounds');
      cb^.content[cb^.cursor] := c;
      cb^.cursor := cb^.cursor + 1;
    end;
end;

type
  HexAscii = array [0..1] of char;
function ConvertHexAscii(c : char) : HexAscii;
var
  out : HexAscii;
  nibble : cardinal;
begin
  nibble := cardinal(c) and (15);

  if nibble < 10 then
    out[1] := char(nibble + cardinal('0'))
  else
    out[1] := char(nibble - 10 + cardinal('A'));

  nibble := (cardinal(c) shr 4) and (15);

  if nibble < 10 then
    out[0] := char(nibble + cardinal('0'))
  else
    out[0] := char(nibble - 10 + cardinal('A'));

  exit (out);
end;

procedure WriteHexAscii(cb : pCursorBuffer; c : char);
var
  dat : HexAscii;
begin
  dat := ConvertHexAscii(c);
  CursorBufferWrite(cb, dat[0]);
  CursorBufferWrite(cb, dat[1]);
end;

procedure CursorBufferWriteMultiple(cb : pCursorBuffer; buf : acRawStr);
var
  i : cardinal;
begin
  i := 0;
  while (buf[i] <> char(0)) and (i < sizeof(acRawStr)) do
    begin
      CursorBufferWrite(cb, buf[i]);
      i := i + 1;
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