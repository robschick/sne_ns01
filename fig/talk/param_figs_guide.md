---
title: "NARWC 2026 — What the Parameter Figures Say"
subtitle: "Plain-language notes and one question to prepare for each figure"
date: "23 October 2026"
geometry: margin=1in
fontsize: 11pt
mainfont: "Helvetica Neue"
colorlinks: true
header-includes:
  - \usepackage{titlesec}
  - \titlespacing*{\subsection}{0pt}{1.4ex}{0.6ex}
  - \usepackage{float}
  - \floatplacement{figure}{H}
---

**What these are.** Four candidate slides that turn the fitted parameters into
something the room can picture. Suggested use for a 1–2 minute slot: **Fig 4
then Fig 6 (NS01)**, with Fig 2 and Fig 7 held back for questions.

**Numbers.** These figures use clean COX01 (Aug) and the Sep NS01/NS02 100k fits.
NS01/NS02 may shift a little once the 150k chains finish.

**The one rule.** The model only ever sees calls *the detector picked up*.
Anything about noise is about **what we detect**, not what the whales do.
Say "detected" every time.

*Who's asking* says who is most likely to raise the question. *Hit* lists what
a good answer must cover.

# Fig 4 — Turn the ocean up 5 dB

![](volume_knob.png){width=95%}

**What it shows.** Take ten calls on a typical day. Make the ocean 5 dB
noisier, which is about one ordinary day-to-day swing at these buoys. We then
still detect about **5 of the 10 at COX01 and NS02, and about 3 at NS01**
(48%, 47%, 29%).

**How to say it.** "Noise is the single biggest thing between us and the
calls. A noisier-than-usual day can cost us half of what's out there, and at
NS01 more than two-thirds."

**How it's built.** It uses the noise coefficient from each buoy's fit. The
model measures noise in standard deviations, which we converted to
dB re 1 µPa (RMS) from the raw noise files. One typical swing is 4.0 dB at
COX01, 6.0 dB at NS01 and 5.3 dB at NS02, so "+5 dB" is roughly one swing
everywhere.

## Question to prepare: "Is 5 dB a lot? How noisy does it actually get out there?"

*Who's asking:* acousticians, managers, anyone who works with sound levels.

*Hit:*

- 5 dB is an ordinary day, not an extreme one. It's about one standard
  deviation of the noise at each buoy.
- The gap between the quietest 10% of times and a typical (median) time is
  about 5–7 dB at all three buoys:
    - COX01: 72.9 vs 77.6 dB
    - NS01: 77.6 vs 84.2 dB
    - NS02: 76.8 vs 82.5 dB
- In power terms, +3 dB doubles the sound energy, so +5 dB is about 3×.
- Why NS01 is more sensitive: **we don't know yet**. Possible reasons are
  different noise sources (vessels vs weather), how sound travels at that
  site, or how far the detector can hear. Don't guess on stage. Say it's on
  the list.

# Fig 6 — Calls missing on noisy days

![](quiet_season_ns01.png){width=95%}

**What it shows.** The grey area is the expected number of detected calls
per day. The blue areas show how many more there would be if noise had stayed
at each buoy's own quietest-10% level all season. Times that were already
that quiet are left as they were.

- **Dark blue:** contact calls we'd have gained.
- **Light blue:** the answers those calls would have drawn. Each contact call
  brings about 1.5 answers on average.

**Over the season**, about half to 60% of the calls we'd hear in quiet
conditions are missing:

| Buoy | Detected | Missing |
|---|---|---|
| COX01 | ~6,100 | ~5,400 (47%) |
| NS01 | ~13,000 | ~17,700 (58%) |
| NS02 | ~33,600 | ~53,700 (61%) |

At NS01 the gap piles up in the busy Jan–Feb peaks, which are also the noisy
part of the season.

**How to say it.** "If the ocean had stayed as quiet as its quietest days,
we'd have heard roughly twice as many calls. That's either calls we missed, or
calls that were never made, and from detections alone we can't tell which."

**The baseline.** "Quiet" means the quietest 10% of times *at that buoy*, not
a pristine ocean. The comparison stays inside conditions we actually
recorded.

## Question to prepare: "So is noise making the whales stop calling?"

*Who's asking:* conservation groups, managers, the press, anyone thinking
about vessels or offshore wind.

*Hit:*

- **We can't tell from detections alone.** There are two explanations, and
  the model can't separate them:
    - **masking:** the whales called and the detector missed the calls;
    - **behavior:** the whales called less, or stopped.
- It could be both, in any mix. The slide says so on purpose.
- Right whales do fight back against noise. Tagged whales raised their call
  amplitude in step with background noise, which kept their signal-to-noise
  ratio about the same, *at moderate noise levels* (Parks et al. 2011).
- That makes our large drop in detections more interesting, not less. If the
  whales fully kept pace, a distant recorder would lose few calls to masking.
  So either they can't keep pace at these noise levels, or they call less.
  Parks et al. raise both: there is "a physical limit to the maximum source
  level", and beyond it whales "will have to wait until the noise levels are
  lower to call."
- If pressed: that study was tags on summer feeding whales in the Bay of
  Fundy, measured over a different noise band (20 Hz–8 kHz). Don't compare
  their dB numbers with ours.
- Citation: Parks, S. E., Johnson, M., Nowacek, D., & Tyack, P. L. (2011).
  Individual right whales call louder in increased environmental noise.
  *Biology Letters*, 7(1), 33–35. doi:10.1098/rsbl.2010.0451
- Separating masking from behavior takes other data:
    - detection-range or propagation studies, to measure how far the detector
      hears at each noise level;
    - tags on individual whales;
    - recorders spaced closer together.
- Not a causal finding. Noise here is a covariate, not an experiment.

# Fig 2 — Same conversation, different crowds

![](same_conversation.png){width=95%}

**What it shows.**

- **Left:** how long an exchange is. At every buoy, a bit over half of
  exchanges (55%) are a single call that nobody answers. The rest run 2, 3 or
  more calls, and the average is **2.5 calls**. The three buoys' bars are
  nearly identical.
- **Right:** how many exchanges start each day. About **16 at COX01, 34 at
  NS01 and 89 at NS02**, more than five times as many at NS02 as at COX01.

**How to say it.** "The whales follow the same rules everywhere. A call gets
an answer about 60% of the time, and the urge to answer fades within a
couple of minutes. NS02 isn't chattier. It just has more whales starting
conversations."

**Where the numbers come from.** Each call draws on average α/η ≈ 0.6
answers, so the length of an exchange follows directly from that one number.
The half-life of the urge to answer is about 2 minutes at COX01 and NS01 and
1.4 minutes at NS02.

## Question to prepare: "Is an 'answer' really another whale? Couldn't it be the same whale calling again?"

*Who's asking:* right whale acousticians and behavior researchers. This is
the sharpest question in the room.

*Hit:*

- **Fair point: the model doesn't know who called.** An "answer" is any call
  that the timing says was *triggered* by an earlier one, within a few
  minutes.
- That includes one whale calling in a bout (repeating itself) as well as
  call-and-response between whales.
- So "exchange" means a **burst of linked calls**. It doesn't have to be a
  two-whale dialogue.
- What the model does show is that calls are *contagious* in time, and the
  same way at all three sites.
- Telling repeats from replies would take directional or localising arrays,
  or tags.

# Fig 7 — What moved the call rate (backup)

![](rate_drivers_ns01.png){width=95%}

**What it shows.** Day by day, how much each part of the model pushed the
detected call rate up or down. 1× is a typical day for that driver, 10× means
it multiplied the rate tenfold, and 0.1× means it cut the rate to a tenth.

- **Noise** swings the most, from about 0.03× to 20× day to day. That's the
  same story as Figs 4 and 6.
- **"Water temperature"** is a smooth climb from Oct to Feb. This is really
  the season. The water cools steadily while the whales arrive.
- **Seasonal cycles** (daily to two-monthly rhythms) move the rate by a few-fold.
- **Leftover** is what the model can't explain with the covariates. It gets
  bigger in Jan–Feb.
- **Answering** is 1× on days with no calls and about 1.6× on a typical
  calling day.

**How to say it.** "Day to day, noise moves what we detect more than anything
else. The long rise through winter tracks the season, and some of the
variation is still unexplained."

## Why the season shows up in "water temperature," not the cycles

The model has two ways to describe the season. They do different jobs.

- **The harmonics only describe rhythms.** The cycles run from 1 day to
  2 months, and the window is 151 days, so even the longest cycle repeats
  about 2.5 times. A sine wave always comes back to where it started, so no
  mix of them can make a steady rise from October to February. That's why the
  "Seasonal cycles" panel wobbles around 1× with no trend. The leftover term
  can't carry the trend either, because it only remembers about 3 hours.
- **SST is the only smooth, one-way term.** Water temperature falls almost in
  a straight line over the window:

| Buoy | SST, Oct 1 to Mar 1 | Correlation with day of season |
|---|---|---|
| COX01 | 19.4 to 4.9 °C | −0.99 |
| NS01 | 19.4 to 3.8 °C | −0.98 |
| NS02 | 19.6 to 6.1 °C | −0.96 |

- So SST works as **a clock for the season**. Whatever builds up steadily
  through the winter, mostly whales arriving, is credited to SST. That's why
  its swing is so large: about 10× to 250× across the season, more than the
  harmonics at every buoy.
- **History.** The seasonal spline tried over the summer was meant to model
  that trend directly. It was set aside: at 7 months it never passed the
  convergence check, and the 5-month window didn't need it. In the current
  model, **SST is the seasonal-trend term in practice**, and its coefficient
  shouldn't be read as an effect per °C.

**How to say it.** "Two parts of the model describe the season. The cycles
capture the rhythms: daily, weekly, monthly. Water temperature captures the
long build-up through winter. Temperature falls so steadily that we can't
separate 'colder water' from 'later in the season'. So read that line as *the
season*, not as a temperature effect."

**If asked "So why include SST at all?"**

- The season needs a trend term, and SST is a physically meaningful one, even
  though with one winter it can't be separated from time.
- Several winters, or sites where temperature and season don't move together,
  would let it be tested properly.
- The harmonics are the part we can interpret, as recurring rhythms.

**Possible figure changes:** relabel the strip "Season (via water
temperature)" for the talk; for the paper, consider one combined "Season"
panel (SST + cycles) with the cycles alone drawn as a lighter line.

## Question to prepare: "Does cold water bring the whales in, and warmer water push them out?"

*Who's asking:* oceanographers, climate-minded audience members, managers
thinking about shifting distributions.

*Hit:*

- **No, not from this.** Water temperature here is mostly a stand-in for
  *the season*. It falls steadily from October to February, the same months
  the whales build up.
- With one winter of data, temperature and time of year can't be pulled
  apart, so the temperature line is a seasonal trend, not a threshold.
- Testing temperature itself needs several years, or sites where temperature
  and season don't move together.
- Same caveat as noise: these are associations in detections, not causes.

# Quick reference

| | COX01 | NS01 | NS02 |
|---|---|---|---|
| Still detected after +5 dB | 48% | 29% | 47% |
| One typical noise swing | 4.0 dB | 6.0 dB | 5.3 dB |
| Calls missing on noisy days | ~5,400 (47%) | ~17,700 (58%) | ~53,700 (61%) |
| Calls answered | 60% | 61% | 60% |
| Calls per exchange | 2.5 | 2.6 | 2.5 |
| Exchanges started per day | 16 | 34 | 89 |
| Half-life of the urge to answer | 2.0 min | 1.9 min | 1.4 min |
