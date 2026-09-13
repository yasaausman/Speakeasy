# Hindi appointment demo — target 2:45

Working name: **KindlyCall**. Replace only after the team chooses a name.

Promise: **Book everyday appointments in your language—even when the business only speaks English.**

This is a recording script, not evidence that the described real call has happened. The built-in UI rehearsal is explicitly simulated and cannot establish real-world task completion.

## 0:00–0:20 — The person and the task

Show a real team member or consenting tester holding the iPhone. Use their actual situation; do not invent a personal history.

English narration:
> Booking an appointment can take one phone call—if you speak the language. We built KindlyCall for someone who knows what they need but needs help handling that English conversation.

If a tester offers a useful observation, use their words with permission. No fabricated testimonial or population statistic is needed.

## 0:20–0:45 — Hindi request and approval

Hindi request (adjust the day and business to the actual arranged test):
> मेरे लिए मंगलवार दोपहर तीन बजे दाँतों की जाँच का अपॉइंटमेंट बुक कर दीजिए। अगर तीन बजे समय न मिले, तो साढ़े तीन बजे भी ठीक है।

English subtitle:
> Book me a dental checkup Tuesday at 3 p.m. If 3 isn't available, 3:30 is fine too.

Show the detected/selected Hindi language, business name, number, address, translated readback, and the user approving the call. Keep private details off the public recording. The number and destination must be explicitly approved before a real call.

English narration:
> They speak in Hindi, check who will be called, and approve the request. Their preferred time and fallback are part of the brief.

## 0:45–1:30 — The English call

Show the app running on the iPhone or simulator and genuine CALL-E call footage/audio if available. Capture the AI disclosure, the receptionist's actual answer, and the outcome.

Ideal complication: the first time is unavailable and the agent selects the user's approved fallback. Do not represent an arranged role-play as an unsolicited real business interaction. Do not create an unwanted appointment for a demo. Use a consenting tester acting as receptionist if necessary, labeled **Controlled test · real CALL-E phone connection**.

English narration:
> CALL-E handles the English conversation. The agent has the user's constraints and can answer the questions they've supplied details for.

If waiting time is edited out, label **Wait shortened**. If the fallback was not actually used, remove that claim.

## 1:30–2:00 — The result, in Hindi

Show the actual result and its narration. Example subtitle structure:
> Appointment confirmed: [actual date/time], [actual business], [actual reference if provided].

Never add a confirmation number or date that the business did not provide. If the date is relative or ambiguous, show the calendar review rather than pretending it was auto-added.

English narration:
> The answer comes back in Hindi, with the information the business confirmed. If the call ends without completing the task, the app says so.

## 2:00–2:25 — Recovery and breadth

Show the separate, clearly labeled simulated missing-name screen if no genuine recovery recording exists. Explain that it asks for the missing fact and brings the user back through confirmation before another call.

One sentence about comparisons is enough:
> It can also ask several businesses for options without booking any of them, then let you choose.

## 2:25–2:45 — Evidence and close

Show a compact code/architecture card: SwiftUI → Fastify → CALL-E MCP. CALL-E is used at runtime through plan_call, run_call, and get_call_run. Translation and business search are separate from the phone conversation.

Use measured results from USER-TEST.md if completed. Otherwise say:
> We have automated tests for the call workflow and Hindi interface. Our next step is testing the complete experience with Hindi-speaking users.

Closing:
> Your words. We make the call.

## Recording preparation

- Prefer one continuous recording of the complete task; edit a copy to under 3 minutes.
- Record on the actual app, with Hindi selected. Use English captions for judging.
- Capture a backup recording before further cosmetic changes.
- Recheck the public video link signed out after uploading.
- Submit the Devpost form before **September 14, 2026, 10:45 a.m. America/Chicago** (11:45 p.m. SGT).
- The team still needs to supply the real-call recording, participant permission, account email, and public video URL. Do not fill these with invented information.

Source: https://call-e.devpost.com/rules (checked September 13, 2026).
