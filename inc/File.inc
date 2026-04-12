{$ifndef __FILE_INC__}
{$define __FILE_INC__}

{ TODO: Memory-backed files }

const
  CHAR_EOF = char(6);

type
  pChar = ^char;

  FileKind = (FILE_DISK, FILE_MEM);
  FileMode = (FMODE_READ, FMODE_WRITE);
  TextFile = record
    mode : FileMode;
    case kind : FileKind of
      FILE_DISK : (handle : file of char);
      FILE_MEM : (curOffset, length : cardinal; content : pChar);
  end;
  pTextFile = ^TextFile;

procedure DiskFileOpen(f : pTextFile; name : pChar; mode : FileMode); forward;
procedure MemoryFileOpen(
  f : pTextFile; 
  memory : pChar; 
  length : cardinal; 
  mode : FileMode); forward;
function FileRead(f : pTextFile) : char; forward;
procedure FileWrite(f : pTextFile; c : char); forward;
procedure FileSeek(f : pTextFile; pos : cardinal); forward;
function FileGetPosition(f : pTextFile) : cardinal; forward;
function IsFileEof(f : pTextFile) : boolean; forward;
procedure FileClose(f : pTextFile); forward;

{$ifdef __IMPL__}
{$include "inc/Assert.inc"}

procedure DiskFileOpen(f : pTextFile; name : pChar; mode : FileMode);
begin
  f^.kind := FILE_DISK;
  assign(f^.handle, name);

  if mode = FMODE_WRITE then
    rewrite(f^.handle)
  else if mode = FMODE_READ then
    reset(f^.handle);

  f^.mode := mode;
end;

procedure MemoryFileOpen (
  f : pTextFile; 
  memory : pChar; 
  length : cardinal; 
  mode : FileMode
);
begin
  f^.kind := FILE_MEM;
  f^.curOffset := 0;
  f^.length := length;
  f^.content := memory;
  f^.mode := mode;
end;

function FileRead(f : pTextFile) : char;
var
  output : char;
begin
  output := char(0);
  Assert(f^.mode = FMODE_READ, 'Attempted read from non-readable file', 37);
  
  if f^.kind = FILE_DISK then
    read(f^.handle, output)
  else if (f^.curOffset >= f^.length) then
    output := CHAR_EOF
  else
    begin
      output := f^.content[f^.curOffset];
      f^.curOffset := f^.curOffset + 1;
    end;
  
  exit (output);
end;

procedure FileWrite(f : pTextFile; c : char);
begin
  Assert(f^.mode = FMODE_WRITE, 'Attempted write to non-writable file', 36);
  
  if f^.kind = FILE_DISK then
    write(f^.handle, c)
  else
    begin
      Assert(f^.curOffset < f^.length, 'Write out of bounds', 19);
      f^.content[f^.curOffset] := c;
      f^.curOffset := f^.curOffset + 1;
    end;
end;

procedure FileSeek(f : pTextFile; pos : cardinal);
begin

  if f^.kind = FILE_DISK then
    seek(f^.handle, pos)
  else
    begin
      Assert(pos <= f^.length, 'Cannot seek out of bounds', 25);
      f^.curOffset := pos;
    end;
end;

function FileGetPosition(f : pTextFile) : cardinal;
begin
  if f^.kind = FILE_DISK then
    exit (filepos(f^.handle));
  
  exit (f^.curOffset);
end;

function FileLength(f : pTextFile) : cardinal;
begin
  if f^.kind = FILE_DISK then
    exit (FileSize(f^.handle));

  exit (f^.length);
end;

function IsFileEof(f : pTextFile) : boolean;
begin
  if f^.kind = FILE_DISK then
    exit (eof(f^.handle));

  exit (f^.curOffset >= f^.length);
end;

procedure FileClose(f : pTextFile);
begin
  if f^.kind = FILE_DISK then Close(f^.handle);
end;

{$endif}
{$endif}