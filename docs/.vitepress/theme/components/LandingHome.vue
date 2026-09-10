<script setup lang="ts">
import { withBase } from 'vitepress'
</script>

<template>
  <main class="claudux-home">
    <section class="intro">
      <div>
        <h1>Update the docs.<br />Keep your words.</h1>
        <p class="lead">Ask Claude Code or Codex to document a code change. Pin the sections you wrote, then review the bounded patch.</p>
        <a class="action" href="#try-it">Run an authenticated demo</a>
      </div>
      <img class="mark" :src="withBase('/claudux-icon.png')" alt="A paper stack with a violet clip" />
    </section>
    <figure>
      <video controls preload="metadata" :poster="withBase('/claudux-demo.png')" aria-label="Claudux protected-section demo">
        <source :src="withBase('/claudux-demo.mp4')" type="video/mp4" />
        <a :href="withBase('/claudux-demo.mp4')">Watch the demo</a>
      </video>
      <figcaption>The recorded run updates the API section while the source, pinned Quick start, and original fixture stay unchanged.</figcaption>
    </figure>
    <section class="try" id="try-it">
      <div>
        <h2>Give your agent one clear job.</h2>
        <p>Open the checkout in Claude Code or Codex and give it the prompt below. The helper creates a temporary Git project with a pinned Quick start and editable API section; Claudux checks the returned patch.</p>
        <p>Python 3, Node 18+, Bash, and an authenticated Claude Code or Codex CLI.</p>
      </div>
      <div>
        <pre>Run examples/agent-demo/run.sh. In two bullets, 35 words maximum: state the API change, then whether source, pinned Quick start, and original fixture stayed unchanged.</pre>
        <a :href="withBase('/guide/installation')">Install Claudux for your project ↗</a>
      </div>
    </section>
    <section class="explain">
      <h2>You decide what can change.</h2>
      <p>A committed manifest identifies the pages, generated sections, and pinned text. In manifest mode, the coding agent returns patches and Claudux checks the batch before writing.</p>
      <p>Without a manifest, the backend writes docs directly. With either approach, a reviewable diff is the result: you still check that the explanation is right.</p>
      <p><a :href="withBase('/technical/deterministic-generation')">Read the manifest guide ↗</a></p>
    </section>
    <footer>
      <a :href="withBase('/guide/commands')">CLI command reference</a>
      <span><a href="https://github.com/firstbitelabsllc/claudux/blob/main/LICENSE">MIT license</a> · <a href="https://github.com/firstbitelabsllc/claudux/issues">Report a problem</a></span>
    </footer>
  </main>
</template>

<style scoped>
.claudux-home {
  max-width: 1160px;
  padding: 32px 48px 56px;
  margin: auto;
  font-size: 18px;
  line-height: 1.65;
}
.intro {
  display: grid;
  grid-template-columns: 1.65fr 1fr;
  gap: 24px;
  align-items: center;
  padding: 32px 0 48px;
}
h1 {
  font-size: clamp(52px, 6.4vw, 80px);
  font-weight: 500;
  line-height: 1.06;
  letter-spacing: -0.04em;
  text-wrap: balance;
  margin: 0 0 24px;
}
.lead {
  font-size: 21px;
  color: #695d75;
  max-width: 50ch;
  margin: 0 0 28px;
}
.mark {
  width: 100%;
  max-width: 340px;
}
.action {
  display: inline-block;
  background: #322940;
  color: #f4f2eb;
  border-radius: 5px;
  padding: 12px 24px;
  text-decoration: none;
  font-size: 16px;
}
.action:hover {
  background: #72519c;
  color: #f4f2eb;
}
a {
  text-decoration: underline;
  text-underline-offset: 5px;
}
a:hover {
  color: #72519c;
}
figure {
  margin: 0;
}
video {
  display: block;
  width: 100%;
  border: 1px solid #d0c5d9;
  border-radius: 8px;
}
figcaption {
  font-size: 14px;
  color: #695d75;
  margin-top: 12px;
}
.try {
  display: grid;
  grid-template-columns: 1fr 1.15fr;
  gap: 48px;
  margin-top: 64px;
  border-top: 1px solid #d0c5d9;
  padding-top: 32px;
}
h2 {
  font-size: 32px;
  line-height: 1.2;
  font-weight: 500;
  letter-spacing: -0.03em;
  margin: 0 0 20px;
}
.try p {
  color: #695d75;
  max-width: 44ch;
  margin: 0 0 20px;
}
pre {
  font: 14px/1.9 monospace;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  margin: 0 0 24px;
}
.explain {
  max-width: 72ch;
  margin-top: 48px;
}
.explain p {
  color: #695d75;
  margin: 0 0 16px;
}
footer {
  display: flex;
  justify-content: space-between;
  gap: 24px;
  margin-top: 56px;
  font-size: 14px;
  color: #695d75;
}
@media (max-width: 650px) {
  .claudux-home {
    padding: 24px 24px 40px;
  }
  .intro {
    padding-top: 8px;
    grid-template-columns: 1fr;
  }
  .mark {
    grid-row: 1;
    width: 90px;
  }
  .lead {
    font-size: 19px;
  }
  .try {
    grid-template-columns: 1fr;
    gap: 16px;
    margin-top: 40px;
  }
  footer {
    flex-direction: column;
    gap: 12px;
  }
}
</style>
