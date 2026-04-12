{$ifndef __FILE_INC__}
{$define __FILE_INC__}

{ TODO: Memory-backed files }

type
  FileMode = (FMODE_READ, FMODE_WRITE);
  TextFile = record
    mode : FileMode;
    handle : file of char;
  end;
  pTextFile = ^TextFile;

procedure FileOpen(f : pTextFile; name : pChar; mode : FileMode); forward;
function FileRead(f : pTextFile) : char; forward;
procedure FileWrite(f : pTextFile; c : char); forward;
procedure FileSeek(f : pTextFile; pos : cardinal); forward;
function FileGetPosition(f : pTextFile) : cardinal; forward;
function IsFileEof(f : pTextFile) : boolean; forward;
procedure FileClose(f : pTextFile); forward;

{$ifdef __IMPL__}
{$include "inc/Assert.inc"}

procedure FileOpen(f : pTextFile; name : pChar; mode : FileMode);
begin
  assign(f^.handle, name);

  if mode = FMODE_WRITE then
    rewrite(f^.handle)
  else if mode = FMODE_READ then
    reset(f^.handle);

  f^.mode := mode;
end;

function FileRead(f : pTextFile) : char;
var
  output : char;
begin
  output := char(0);
  Assert(f^.mode = FMODE_READ, 'Attempted read from non-readable file', 37);
  read(f^.handle, output);
  exit (output);
end;

procedure FileWrite(f : pTextFile; c : char);
begin
  Assert(f^.mode = FMODE_WRITE, 'Attempted write to non-writable file', 36);
  write(f^.handle, c);
end;

procedure FileSeek(f : pTextFile; pos : cardinal);
begin
  seek(f^.handle, pos);
end;

function FileGetPosition(f : pTextFile) : cardinal;
begin
  exit (filepos(f^.handle));
end;

function FileLength(f : pTextFile) : cardinal;
begin
  exit (FileSize(f^.handle));
end;

function IsFileEof(f : pTextFile) : boolean;
begin
  exit (eof(f^.handle));
end;

procedure FileClose(f : pTextFile);
begin
  Close(f^.handle);
end;

{$endif}
{$endif}