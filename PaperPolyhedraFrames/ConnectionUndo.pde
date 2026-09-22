// CONNECTIONUNDO.PDE - Undo/redo for connection editing
//
// Ctrl+Z / Ctrl+Y while connecting, in the 3D view or on the flat pattern.
//
// SCOPE. This undoes CONNECTIONS -- joining, detaching, moving, spinning, flipping -- and
// nothing else. It is not a general undo for the sketch: sliders, textures, cutouts and
// markers are untouched by it. Connecting is the one part of the tool where a wrong click
// silently rearranges an assembly, which is why it gets one and the sliders do not.
//
// HOW. The connection set is tiny -- a handful of small objects -- so there is no need for a
// command log with an inverse for every operation. Each edit pushes a deep copy of the whole
// list, and undo swaps a copy back in. Whole-state snapshots cannot drift out of step with
// the thing they describe the way paired do/undo methods can.
//
// WHAT INVALIDATES IT. A connection names its two shapes by INDEX, so any change to the
// shape list can leave a stored snapshot describing an assembly that no longer exists.
// Deleting a shape shifts every index above it; importing replaces the lot. Both throw the
// history away rather than let undo resurrect a connection pointing at the wrong shape.
// Adding a shape is safe -- it only appends -- so it keeps the history. Restores are
// re-validated anyway, so a snapshot that has gone stale drops the bad entries instead of
// crashing.

class ConnectionSnapshot {
  ArrayList<Connection> conns;
  int selected;
}

ArrayList<ConnectionSnapshot> _connUndo = new ArrayList<ConnectionSnapshot>();
ArrayList<ConnectionSnapshot> _connRedo = new ArrayList<ConnectionSnapshot>();

final int CONNECTION_UNDO_DEPTH = 60;

// Consecutive edits of the same kind on the same connection collapse into one step, so a
// drag or a held arrow key costs one undo rather than one per frame. A new gesture -- a
// different key, a different connection, or a pause -- starts a fresh step.
final int CONNECTION_UNDO_COALESCE_MS = 700;
String _lastUndoTag = "";
int _lastUndoAt = -100000;

ConnectionSnapshot snapshotConnections() {
  ConnectionSnapshot s = new ConnectionSnapshot();
  s.conns = new ArrayList<Connection>();
  if (connections != null) {
    for (Connection c : connections) s.conns.add(copyConnection(c));
  }
  s.selected = selectedConnectionIdx;
  return s;
}

Connection copyConnection(Connection c) {
  Connection n = new Connection(c.parentShapeIdx, c.childShapeIdx,
                                c.parentFaceKind, c.parentFaceIndex, c.posLocal);
  n.childFlipped = c.childFlipped;
  n.spinDeg      = c.spinDeg;
  // Carried across, not reissued: undoing a move must not repaint the pairing marks.
  n.markId       = c.markId;
  return n;
}

// Records the state BEFORE an edit. Call it at the start of the edit, not the end.
// `tag` names the gesture: pass "" for a discrete action that must always be its own step.
void pushConnectionUndo(String tag) {
  int now = millis();
  boolean coalesce = tag != null && !tag.isEmpty() &&
                     tag.equals(_lastUndoTag) &&
                     (now - _lastUndoAt) < CONNECTION_UNDO_COALESCE_MS &&
                     !_connUndo.isEmpty();
  _lastUndoTag = (tag == null) ? "" : tag;
  _lastUndoAt  = now;

  // Same gesture still running: the step already on the stack holds the state it started
  // from, which is the one to come back to. Leave it alone.
  if (coalesce) { _connRedo.clear(); return; }

  _connUndo.add(snapshotConnections());
  while (_connUndo.size() > CONNECTION_UNDO_DEPTH) _connUndo.remove(0);
  _connRedo.clear();   // a fresh edit abandons whatever was undone
}

// Drops entries that no longer describe shapes that exist. A snapshot only goes stale when
// something cleared the history and an edit happened before the clear took effect, but the
// cost of checking is nil next to the cost of a dangling index.
void _applyConnectionSnapshot(ConnectionSnapshot s) {
  connections.clear();
  int nShapes = (shapes == null) ? 0 : shapes.size();
  for (Connection c : s.conns) {
    if (c.parentShapeIdx < 0 || c.parentShapeIdx >= nShapes) continue;
    if (c.childShapeIdx  < 0 || c.childShapeIdx  >= nShapes) continue;
    connections.add(copyConnection(c));
  }
  selectedConnectionIdx = constrain(s.selected, -1, connections.size() - 1);
  // The drag state points into the old list; it must not survive the swap.
  draggedConnectionIdx = -1;
  draggedFace          = null;
  draggedPanelConnIdx  = -1;
  _lastUndoTag = "";   // the next edit starts a new gesture
}

boolean undoConnections() {
  if (_connUndo.isEmpty()) {
    println("[Undo] Nothing to undo");
    return false;
  }
  _connRedo.add(snapshotConnections());
  _applyConnectionSnapshot(_connUndo.remove(_connUndo.size() - 1));
  println("[Undo] " + connections.size() + " connection(s); " + _connUndo.size() + " step(s) left");
  return true;
}

boolean redoConnections() {
  if (_connRedo.isEmpty()) {
    println("[Redo] Nothing to redo");
    return false;
  }
  _connUndo.add(snapshotConnections());
  _applyConnectionSnapshot(_connRedo.remove(_connRedo.size() - 1));
  println("[Redo] " + connections.size() + " connection(s)");
  return true;
}

// Called when the shape list changes in a way that renumbers it. See the header.
void invalidateConnectionUndo(String why) {
  if (_connUndo.isEmpty() && _connRedo.isEmpty()) return;
  _connUndo.clear();
  _connRedo.clear();
  _lastUndoTag = "";
  println("[Undo] History cleared: " + why);
}

boolean canUndoConnections() { return !_connUndo.isEmpty(); }
boolean canRedoConnections() { return !_connRedo.isEmpty(); }
