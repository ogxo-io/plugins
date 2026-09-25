# Architectural Anti-Patterns

Common architectural anti-patterns, their symptoms, root causes, and remedies. Use this reference when reviewing an existing architecture or evaluating whether a proposed design risks falling into known traps.

## Big Ball of Mud

**Symptom**: No discernible architecture, any component can depend on any other, changing one thing breaks everything.
**Root Cause**: No module boundaries, shortcuts taken under time pressure, no architectural governance.
**Remedy**: Identify bounded contexts, establish module boundaries, enforce dependency rules incrementally. Start with the strangler fig pattern around the messiest areas.

## Distributed Monolith

**Symptom**: Multiple services that must be deployed together, share databases, or have synchronous call chains.
**Root Cause**: Decomposed by technical layer instead of business capability, shared database, tight coupling through synchronous calls.
**Remedy**: Identify true service boundaries (business capabilities), give each service its own data store, use async communication where possible. Consider consolidating back to a modular monolith if independence is not needed.

## Golden Hammer

**Symptom**: Using the same technology or pattern for every problem regardless of fit.
**Root Cause**: Familiarity bias, organizational inertia, fear of learning new approaches.
**Remedy**: Evaluate each architectural decision on its own merits. Use the trade-off analysis framework. Choose boring technology for most things, innovative technology only where it provides decisive advantage.

## Premature Decomposition

**Symptom**: Splitting into microservices before understanding domain boundaries, resulting in wrong service boundaries that require cross-service refactoring.
**Root Cause**: Applying microservices prematurely, copying architecture from larger organizations without matching context.
**Remedy**: Start with a monolith or modular monolith. Discover domain boundaries through experience. Decompose only when you have proven need for independent deployment or scaling of a specific capability.

## Resume-Driven Architecture

**Symptom**: Technology choices driven by what is trendy rather than what solves the problem.
**Root Cause**: Engineers wanting to learn new technology on company time, hype-driven decision making.
**Remedy**: Require ADRs for all significant technology choices. Evaluate against quality attribute requirements, not novelty. Prefer boring technology that the team already knows.

## Accidental Complexity

**Symptom**: System is far more complex than the problem it solves. Layers of abstraction that add indirection without value.
**Root Cause**: Over-engineering, anticipating requirements that never materialize, not revisiting early decisions.
**Remedy**: Apply YAGNI (You Ain't Gonna Need It). Add complexity only when driven by actual requirements. Regularly review and simplify. Question every layer of indirection.
