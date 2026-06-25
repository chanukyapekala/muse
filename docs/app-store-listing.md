# Muse — App Store Listing Copy

Paste-ready text for App Store Connect. Character limits noted next to each field.

---

## App Name (30 chars max)

```
Muse — Private On-Device AI
```
(28 chars)

Alternative if "On-Device" reads as jargon:
```
Muse — Private AI Chat
```
(22 chars)

---

## Subtitle (30 chars max)

```
On-device. No accounts.
```
(23 chars)

Alternative:
```
AI that never leaves your phone
```
(31 — too long, trim if you want this one: "AI that stays on your phone" — 27)

---

## Promotional Text (170 chars max — can change anytime without re-review)

```
A private AI assistant that runs entirely on your iPhone. No accounts, no API keys, no cloud. Your conversations never leave your device.
```
(137 chars)

---

## Keywords (100 chars max, comma-separated — spaces count)

```
AI,chat,assistant,private,offline,on-device,local,LLM,no signup,no account,privacy,personal AI
```
(94 chars)

Notes:
- Avoid competitor trademarks (ChatGPT, Claude, Gemini, Copilot) — Apple flags these.
- "AI assistant" already takes 13 chars combined with separators; trim if you want to add another.

---

## Description (4000 chars max)

```
Muse is a private AI chat app that runs entirely on your iPhone. No accounts. No API keys. No subscriptions. Your conversations never leave your device.

WHY MUSE

Most AI apps send your every word to a server. Muse doesn't. Open the app, ask anything, and an AI model running directly on your iPhone replies. The internet isn't involved.

THAT MEANS

• Private by design — no message ever transmitted, no account ever required.
• Offline — works on a plane, on the subway, in a tent. Once installed, no network needed.
• No subscription — pay once at install (if charged), never asked again.
• No data harvested — Muse can't collect what it never sees.

WHAT IT CAN DO

• Chat naturally — ask, follow up, refine. Conversation context is remembered across messages.
• Voice input — dictate prompts using Apple's on-device speech recognition. Audio stays on your phone.
• Topic graph (Aura) — Muse quietly clusters your prompts into seven categories (AI, Code, Data, Personal, Health, Creative, Work) so you can see what you've been thinking about. Tap any node to revisit past conversations on that topic.
• Chat history — every conversation persists locally, just like a messaging app. Search and revisit anytime.
• Share to any app — send responses to WhatsApp, Messages, Notes, or anywhere else iOS shares to.
• Quick prompts — draft a WhatsApp message, write an Instagram caption, or compose a tweet with one tap.

UNDER THE HOOD

Muse uses Llama 3.2 1B, a compact language model, running via Apple's MLX framework on the iPhone's neural-capable hardware. The model is downloaded once on first launch (~700 MB) and cached locally. After that, the app is fully offline.

PRIVACY POLICY

Everything Muse does is documented here: https://chanukyapekala.github.io/muse/privacy

If a feature collects nothing, the policy says so. If something needs network (first-launch model download), the policy explains exactly why.

WHO IT'S FOR

• Students who want AI help without paying a subscription.
• Privacy-conscious people who don't want their thoughts on someone's server.
• Travellers who need an assistant in airplane mode.
• Anyone tired of "create an account to continue".

Muse is free to try and always private. We hope you'll find it useful.
```

---

## What's New in this Version (4000 chars max — for version 1.0)

```
Welcome to Muse 1.0.

• Chat with a private AI assistant that runs entirely on your iPhone.
• No accounts, no API keys, no subscriptions.
• Voice input via Apple's on-device speech recognition.
• Topic graph (Aura) clusters your prompts into seven categories.
• Chat history persists locally — search, revisit, continue any conversation.
• Share responses to WhatsApp, Messages, Notes, or any iOS app.
• Quick-prompt chips for WhatsApp messages, Instagram captions, and tweets.

Thanks for trying Muse. Feedback welcome at chanukya.pekala@gmail.com.
```

---

## App Category

- **Primary:** Productivity
- **Secondary:** Utilities

Reasoning: "Productivity" gets discovered by people looking for tools that help them get things done. "Utilities" is the closest secondary category — Apple flags AI chat apps with no clear category lever.

---

## Age Rating

- **4+** is defensible — no user-generated public content, no in-app purchase, no third-party sign-in, no web access from inside the app.
- If asked about "Unrestricted Web Access": **No.**
- If asked about "User-Generated Content": **No.** (Conversations are local only.)

---

## Required URLs

| Field | URL |
|---|---|
| **Support URL** | https://chanukyapekala.github.io/muse/ |
| **Privacy Policy URL** | https://chanukyapekala.github.io/muse/privacy |
| **Marketing URL** (optional) | https://chanukyapekala.github.io/muse/ |

---

## App Privacy answers (Privacy Nutrition Label)

When App Store Connect asks "What data does your app collect?", the honest answer is:

> **No data collected.**

Detailed answers:
- **Contact Info:** Not collected (the in-app name field is stored in UserDefaults on-device only — not collected by Muse).
- **Health & Fitness:** Not collected.
- **Financial Info:** Not collected.
- **Location:** Not collected.
- **Sensitive Info:** Not collected.
- **Contacts:** Not collected.
- **User Content:** Not collected (conversations stay on-device via SwiftData; chat history is never transmitted).
- **Browsing History:** Not collected.
- **Search History:** Not collected.
- **Identifiers:** Not collected.
- **Purchases:** Not collected.
- **Usage Data:** Not collected.
- **Diagnostics:** Not collected.
- **Other Data:** Not collected.

Apple's "User Content" category includes audio data — confirm the privacy nutrition label notes that voice transcription uses Apple's on-device-only speech recognition and audio is never collected by Muse.

---

## Notes for the reviewer (Review Notes field)

```
Muse is a single-window AI chat app with no accounts, no sign-in, no in-app purchases, and no third-party services that collect data.

On first launch, the app downloads a ~700 MB language model (Llama 3.2 1B in MLX format) from Hugging Face. This is a one-time download. After that, all AI inference runs locally on the device via Apple's MLX framework. No prompts or responses are ever sent to a server.

To test the core flow:
1. Launch the app, wait for the model to download (Wi-Fi recommended).
2. Type any question and hit send. The reply is generated on-device.
3. Try voice input via the microphone icon (uses on-device speech recognition).
4. Tap Aura tab to see the topic clusters built from your prompts.
5. Tap any Aura node to see past prompts in that category.

There are no demo accounts because the app has no accounts at all.
```

---

## Screenshots — required sizes

App Store Connect requires screenshots at the **iPhone 6.7" display** as the minimum baseline:

- **6.7" Display** (iPhone 15/16 Pro Max — 1290 × 2796): 3–10 screenshots
- 6.1", 5.5", and iPad sizes are optional unless you want better presentation on those devices

Suggested 6 screenshots (in order):
1. Chat thread with a real prompt and response (no "Lorem ipsum")
2. Empty state with the personalised greeting + 3 quick-prompt chips
3. Aura graph with several topic nodes populated
4. Aura cluster drill-down (list of past prompts in one category)
5. Voice input mid-recording (the mic-active state)
6. Settings screen showing the on-device privacy label

Tip: take screenshots on a clean install with a populated database so the screens look believable.
