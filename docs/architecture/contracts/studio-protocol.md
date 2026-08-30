# Studio preview history (removed)

The Studio protocol journal, checkpoint store, socket observer, and back/forward
navigation path were removed from the engine. Live Canvas now treats each Test
Live request as a replacement of the single session-scoped temporary candidate.

This file remains as a compatibility marker for links from older worktrees; it
is not an active protocol contract. The durable session record is still the
authority for the original baseline, interrupted Apply recovery, Cancel, and
Restore & close.
