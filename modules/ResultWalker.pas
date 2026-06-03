unit ResultWalker;
interface
uses Memory, Assertion, ParserInterpreter;

type
	{ Handles the given result, returns true if the result 
		was processed successfully }
	fResultHandle = function (res : pParseResult) : boolean;

	rResultHandleRecord = record
		next : ^rResultHandleRecord;
		id : cardinal;
		walkChild, walkSibling : boolean;
		handle : fResultHandle
	end;
	pResultHandleRecord = ^rResultHandleRecord;

	rResultWalker = record
		alloc : pAllocator;
		handles : pResultHandleRecord;
	end;
	pResultWalker = ^rResultWalker;

	eWalkOrder = (
		WALK_ORDER_NCS, { Walk in order: Node, Child, Sibling }
		WALK_ORDER_NSC,
		WALK_ORDER_SNC,
		WALK_ORDER_SCN,
		WALK_ORDER_CSN,
		WALK_ORDER_CNS
	);

function NewResultWalker(a : pAllocator) : pResultWalker;
procedure AddResultHandle(
	w : pResultWalker; id : cardinal; handle : fResultHandle);
function WalkResult(
	w : pResultWalker; res : pParseResult; o : eWalkOrder) : boolean;

implementation

function NewResultWalker(a : pAllocator) : pResultWalker;
var
	output : pResultWalker;
begin
	output := AllocatorAllocate(a, sizeof(rResultWalker));
	output^.alloc := a;
	output^.handles := nil;
	exit (output);
end;

procedure AddResultHandle
	(w : pResultWalker; id : cardinal; handle : fResultHandle);
var
	rec : pResultHandleRecord;
begin
	rec := AllocatorAllocate(w^.alloc, sizeof(rResultHandleRecord));
	rec^.id := id;
	rec^.walkChild := true;
	rec^.walkSibling := true;
	rec^.handle := handle;
	rec^.next := w^.handles;
	w^.handles := rec;
end;

function LookupResultHandle
	(w : pResultWalker; id : cardinal) : pResultHandleRecord;
var
	curRec : pResultHandleRecord;
begin
	curRec := w^.handles;
	while curRec <> nil do
		begin
			if curRec^.id = id then exit (curRec);
			curRec := curRec^.next;
		end;

	exit (nil);
end;

function WalkResult
	(w : pResultWalker; res : pParseResult; o : eWalkOrder) : boolean;
var
	rec : pResultHandleRecord;
	output : boolean;
begin
	if res = nil then exit (true);
	rec := LookupResultHandle(w, res^.identifier);
	MakeAssertion(rec <> nil, 'Unhandled result type');

	case (o) of
	WALK_ORDER_NCS, WALK_ORDER_NSC: 
		output := rec^.handle(res);
	WALK_ORDER_CNS, WALK_ORDER_CSN: 
		if rec^.walkChild then output := WalkResult(w, res^.child, o);
	WALK_ORDER_SCN, WALK_ORDER_SNC: 
		if rec^.walkSibling then output := WalkResult(w, res^.sibling, o);
	else
		MakeAssertion(false, 'Unknown walk order');
	end;

	if output then
		case (o) of
		WALK_ORDER_CNS, WALK_ORDER_SNC: 
			output := output and rec^.handle(res);
		WALK_ORDER_SCN, WALK_ORDER_NCS: 
			if rec^.walkChild then 
				output := output and WalkResult(w, res^.child, o);
		WALK_ORDER_CSN, WALK_ORDER_NSC: 
			if rec^.walkSibling then 
				output := output and WalkResult(w, res^.sibling, o);
		else
			MakeAssertion(false, 'Unknown walk order');
		end;

	if output then
		case (o) of
		WALK_ORDER_SCN, WALK_ORDER_CSN: 
			output := output and rec^.handle(res);
		WALK_ORDER_SNC, WALK_ORDER_NSC: 
			if rec^.walkChild then 
				output := output and WalkResult(w, res^.child, o);
		WALK_ORDER_CNS, WALK_ORDER_NCS: 
			if rec^.walkSibling then 
				output := output and WalkResult(w, res^.sibling, o);
		else
			MakeAssertion(false, 'Unknown walk order');
		end;

	exit (output);
end;



end.