# Node when under Verifying but does not meet benchmark requirements but not result in Failed on UI

## Issue

- When node is under verifying, stucks for 2-3 days on web Admin under Verifying status.
- Check log and see that Scheduler(Fisherman) reported to Portal that node failed the benchmark test
- But the UI did not inform user about reason not finished verifying, result in Fail
- Because the Portal automatically send request to verify the node every \* times, so the Node stay at Verifying even though it failed

## Solution
