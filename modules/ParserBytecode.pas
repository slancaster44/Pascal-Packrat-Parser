unit ParserBytecode;
interface

uses CursorBuffer;

type
  ParserOpcode = (
    PARSE_OP_MATCH, { format: <opcode> <char> }
    PARSE_OP_RANGE, { format: <opcode> <least char> <most char> }
    PARSE_OP_SEQ, {format: <opcode> <left_hi> <left_lo> <right_hi> <right_lo> }
    PARSE_OP_ALT, {format: <opcode> <left_hi> <left_lo> <right_hi> <right_lo> }
    PARSE_OP_KLEENE, { format: <opcode> <child_hi> <child_lo> }
    PARSE_OP_RES {format: <opcode> <child_hi> <child_lo> }
  );

function ParserInstructionLength(op : ParserOpcode) : cardinal;
procedure WriteParseOpMatch(cb : pCursorBuffer; c : char);
procedure WriteParseOpRange(cb : pCursorBuffer; min, max : char);
procedure WriteParseOpSequence(cb : pCursorBuffer; left, right : cardinal);
procedure WriteParseOpAlt(cb : pCursorBuffer; left, right : cardinal);
procedure WriteParseOpKleene(cb : pCursorBuffer; child : cardinal);
procedure WriteParseOpResult(cb : pCursorBuffer; child : cardinal);

implementation

uses Assertion, CharManipulation;

function ParserInstructionLength(op : ParserOpcode) : cardinal;
begin
  case (op) of
    PARSE_OP_MATCH: exit (2);
    PARSE_OP_RANGE: exit(3);
    PARSE_OP_SEQ: exit(5);
    PARSE_OP_ALT: exit(5);
    PARSE_OP_KLEENE: exit(3);
    PARSE_OP_RES: exit(3);
  else
    MakeAssertion(false, 'Unknown instruction, unknown length');
  end;
end;

procedure WriteParseOpMatch(cb : pCursorBuffer; c : char);
begin
  CursorBufferWrite(cb, char(PARSE_OP_MATCH));
  CursorBufferWrite(cb, c);
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

procedure WriteParseOpKleene(cb : pCursorBuffer; child : cardinal);
begin
  CursorBufferWrite(cb, char(PARSE_OP_KLEENE));

  CursorBufferWrite(cb, GetHi(child));
  CursorBufferWrite(cb, GetLo(child));
end;

procedure WriteParseOpResult(cb : pCursorBuffer; child : cardinal);
begin
  CursorBufferWrite(cb, char(PARSE_OP_RES));

  CursorBufferWrite(cb, GetHi(child));
  CursorBufferWrite(cb, GetLo(child));
end;

end.