impl<const STREAM_CAPACITY: usize> DeneEngineCore<STREAM_CAPACITY> {
    /// Acknowledges an active evidential trap and clears the pipeline stall state.
    #[inline(always)]
    pub fn acknowledge_trap(&mut self) {
        // In the bare-metal core, this resets fault flags and aligns execution vectors.
        self.accumulator = 0;
    }

    /// Evaluates if the current state satisfies strict hardware-invariance.
    #[inline(always)]
    pub fn verify_invariants(&self) -> bool {
        self.stream.len <= STREAM_CAPACITY
    }
}
