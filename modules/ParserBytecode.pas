unit ParserBytecode;
interface

uses CursorBuffer;

type
  ParserOpcode = (
    PARSE_OP_RANGE, { format: <opcode> <least char> <most char> }
    PARSE_OP_SEQ, {format: <opcode> <left_hi> <left_lo> <right_hi> <right_lo> }
    PARSE_OP_ALT, {format: <opcode> <left_hi> <left_lo> <right_hi> <right_lo> }
    PARSE_OP_RES {format: <opcode> <child_hi> <child_lo> }
  );

function ParserInstructionLength(op : ParserOpcode) : cardinal;
procedure WriteParseOpRange(cb : pCursorBuffer; min, max : char);
procedure WriteParseOpSequence(cb : pCursorBuffer; left, right : cardinal);
procedure WriteParseOpAlt(cb : pCursorBuffer; left, right : cardinal);
procedure WriteParseOpResult(cb : pCursorBuffer; child : cardinal);

implementation

uses Assertion, CharManipulation;

function ParserInstructionLength(op : ParserOpcode) : cardinal;
begin
  case (op) of
    PARSE_OP_RANGE: exit(3);
    PARSE_OP_SEQ: exit(5);
    PARSE_OP_ALT: exit(5);
    PARSE_OP_RES: exit(3);
  else
    MakeAssertion(false, 'Unknown instruction, unknown length');
  end;
end;

procedure WriteParseOpRange(cb : pCursorBuffer; min, max : char);
begin
  CursorBufferWrite(cb, char(PARSE_OP_RANGE));
  CursorBufferWrite(cb, min);
  CursorBufferWrite(cb, max);
end;

procedure WriteParseOpSequence(cb : pCursorBuffer; left, right : cardinal);
begin
  CursorBufferWrite(cb, char(PARSE_OP_SEQ));

  CursorBufferWrite(cb, GetHi(left));
  CursorBufferWrite(cb, GetLo(left));

  CursorBufferWrite(cb, GetHi(right));
  CursorBufferWrite(cb, GetLo(right));
end;

procedure WriteParseOpAlt(cb : pCursorBuffer; left, right : cardinal);
begin
  CursorBufferWrite(cb, char(PARSE_OP_ALT));

  CursorBufferWrite(cb, GetHi(left));
  CursorBufferWrite(cb, GetLo(left));

  CursorBufferWrite(cb, GetHi(right));
  CursorBufferWrite(cb, GetLo(right));
end;

procedure WriteParseOpResult(cb : pCursorBuffer; child : cardinal);
begin
  CursorBufferWrite(cb, char(PARSE_OP_RES));

  CursorBufferWrite(cb, GetHi(child));
  CursorBufferWrite(cb, GetLo(child));
end;

end.