---
title: "NARWC 2026 — Questions to Prepare"
subtitle: "Hawkes processes for right whale upcalls at NS01, NS02 and COX01"
date: "21 October 2026"
geometry: margin=1in
fontsize: 11pt
mainfont: "Helvetica Neue"
colorlinks: true
header-includes:
  - \usepackage{titlesec}
  - \titlespacing*{\subsection}{0pt}{1.4ex}{0.6ex}
---

**Audience.** Right whale biologists, managers, lobstermen and fishermen,
students, and conservation groups. Every answer should work for someone who
has never seen a point-process model.

**How to use this.** Record an answer to each question, paste in the
transcript, and we revise it for accuracy against the fits, jargon, length,
and whether it answers the question asked. *Who's asking* says who is most
likely to raise it. *Hit* lists what a good answer must cover.

# Fix before the talk

1. **COX01: Table 3 and Fig 3a use the fit with corrupted timestamps.**
   (Confirmed 21 Oct.) `fig/combined/` dates from 22 June, before the clean
   COX01 refit on 22 August. The clean fit (`fig/cox01/Num.tex`) gives total
   6,096 (5,935–6,234), background 2,462 (2,224–2,677) and **answers 3,633
   (3,404–3,853), which is 60%**. It also gives α = 0.20 and η = 0.34, so
   0.60 answers per call and a 2.0-min half-life. The video is correct, and
   "the same answering at all three sites" holds. Fig 4a already uses the
   clean fit. Replace the COX01 column in Table 3 and use `fig/cox01/XB.pdf`
   for Fig 3a. Caveat: the clean COX01 fit includes a 1-day harmonic, which
   the June NS01/NS02 fits don't (the September NS01 refit has it and gives
   nearly the same counts: 5,066 and 7,947).
2. **The dawn sentence under Fig 6.** The gap ends stay fixed at about 05:00
   UTC all season while dawn moves by an hour. 05:00 UTC is local midnight,
   which points to daily file rollover, not dawn. Cut the claim, or say a
   daily cycle "wasn't modelled and is worth testing."
3. **Fig 1 caption.** It says the Southern New England red circles are
   "Case Study 1"; the legend says Case Study 2.
4. **Fig 4 has no units on the y-axis.**

# The model

## 1. "In plain language, what is this model doing?"

*Who's asking:* everyone, especially students and fishermen.

*Hit:* There are two parts. One is a slowly changing background rate of
calls that start an exchange. The other is a short boost after every call
that fades within a couple of minutes. Explain it with the branching figure,
not Equation 1, in under 60 seconds and without jargon.

## 2. "Why not just count calls, or use a Poisson model?"

*Who's asking:* managers, PAM analysts.

*Hit:* 55–61% of real gaps between calls are under a minute, against 36–42%
under a Poisson model (gap slide). Treating calls as independent mixes up
"more whales calling" with "the same whales talking more," and makes the
uncertainty look smaller than it is.

## 3. "Your intensity plot peaks at 2 to 5. Five what?"

*Who's asking:* students, managers.

*Hit:* Give the unit. Explain background (exchanges starting) versus total
(background plus answers), and why each panel in Fig 4 has a different
y-axis. Use NS02 on 10 January: the total rate was about 310 per hour while
the background was about 95, and the background itself had risen from
about 17.

# What the parameters mean

## 4. "What do α and η actually mean?"

*Who's asking:* biologists, quantitative ecologists.

*Hit:* α/η is the average number of answers each call triggers: about 0.6.
The half-life (ln 2 / η) is about 1.5–2 minutes. So each exchange-starting
call leads to about **2.5 calls in total** (1 / (1 − 0.6)). Use the
branching figure: α/η is "the average number of arrows leaving each dot,"
and the half-life is "how long the arrows usually are." Be ready for why α
on its own (0.16–0.30 per minute) is not "responses per call."

## 5. "So 60% of detections are responses. Should I discount detections by 60%?"

*Who's asking:* managers (they will see Table 3).

*Hit:* No. Responses still show whales are present. What changes is that a
burst isn't evidence of more animals, and the uncertainty is wider than raw
counts suggest.

## 6. "Fig 3 wiggles every few weeks. Are whales on a two-week or lunar cycle?"

*Who's asking:* biologists.

*Hit:* The 1-week to 2-month cycles are a flexible way to fit a smooth
seasonal curve, not a claim that calling repeats on those periods. Don't let
anyone read tides or moon phase into them.

## 7. "Noise and SST have negative effects. Do whales stop calling when it's loud or warm?"

*Who's asking:* fishermen, wind industry, managers, conservation groups.

*Hit:* For noise, it could be masking (the detector misses calls) rather
than a change in behaviour, and the model can't tell the two apart. SST
mostly tracks the season. Neither is a causal finding.

## 8. "Can this tell me how many whales were there?"

*Who's asking:* managers, fishermen. This will come up.

*Hit:* No, and say why. What the model gives instead is a steadier signal
that bursts don't inflate. Say what extra data would let you estimate
abundance.

# Across the three buoys

## 9. "Why is COX01 so different: almost silent until January, then bursts?"

*Who's asking:* biologists, managers for the wind energy areas.

*Hit:* Explain the spatial gradient in Fig 3 (what lies along it; COX01 is
closest to the islands). The number of calls varies about 5-fold, from 6k
to 34k, and when calling happens is local. But the answering structure is
the same at all three sites: about 0.6 answers per call and a half-life of
1.4–2 minutes (confirmed with the clean COX01 fit). That is the strongest
single result.

## 10. "Your Q-Q plot shows misfit. Doesn't that undercut the model?"

*Who's asking:* quantitative ecologists.

*Hit:* The fit is good for 99% of calls. The misfit comes from a few long
true silences when the model expected more calling, not from recording gaps
(coverage is about 99.9%). It's an honest limitation, and it points to
future work: the end-of-season decline, and testing for a daily cycle.

# What this adds, and what's next

## 11. "What does this add to existing habitat and density models?"

*Who's asking:* managers, modellers. This is the "so what" question.

*Hit:* Habitat models work on scales of days to seasons and treat each
detection as independent evidence that whales are present. This model works
on the scale of minutes and social interaction. Some detections are answers
to earlier calls, not new evidence of presence, which matters for
detection-triggered mitigation and for using acoustic data in density
models. Have one concrete management example ready.

## 12. "How do you know it's countercalling, and what's next?"

*Who's asking:* skeptical biologists, students.

*Hit:* The hydrophone records call times only. "Countercall" is our reading
of short-lag clustering. Name the alternatives before the questioner does:
one whale calling in bouts, an animal passing close to the recorder, and how
analysts review detections. The evidence for answering: the same structure
at three sites, and the gap distribution. Next steps: localising callers
with arrays, acoustic tags, signal-to-noise as a mark on each call, the
end-of-season decline estimated from the model, and the spatiotemporal
model linking the buoys. (The full Q&A prep is in
`plans/PLAN_poisson_comparison.md`.)
