# Worked example: splitting a mixed ticket

Read from Step 2 of the routing skill, which defines the risk triggers and
tiers this example applies.

Worked example: a ticket adds a field to a public user payload, a migration
for it, and a language picker in the UI. The new field is a compatible
change to a public contract (trigger 5), so it is the risky part, in the
contained tier: one small task for grok or `implementer-risky` with
`model: "sonnet"`, with the call cap from Step 7, and then the risky-task
review. Had it renamed or removed a field clients read, or changed who may
read it, it would be core risk on the session model. An additive migration
for it is not a trigger by itself. The picker, the translations, and the tests
around them are standard work for `ogxo-route:implementer`, dispatched after
the risky part returns, with its RESULT in the brief. A new dependency, UI work,
translations, and the number of files touched are not triggers. A risky brief
names one trigger and one deliverable; one that lists several triggers, or an
API and its UI together, is two or more tasks. In a real session, whole
tickets briefed as "risky (migration, authorization, wide UI breadth, new
dependency)" ran 2 to 3 hours on one Opus worker and cost the most of any
dispatch.
