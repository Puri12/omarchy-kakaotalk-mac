const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

const nav = document.querySelector(".site-nav");
const navCurrent = nav && nav.querySelector('[aria-current="page"]');
const centerNavCurrent = () => {
  if (!nav || !navCurrent || nav.scrollWidth <= nav.clientWidth) return;
  const navBox = nav.getBoundingClientRect();
  const itemBox = navCurrent.getBoundingClientRect();
  nav.scrollLeft += itemBox.left - navBox.left - (navBox.width - itemBox.width) / 2;
};
centerNavCurrent();
window.matchMedia("(max-width: 900px)").addEventListener("change", centerNavCurrent);

const stack = document.querySelector(".stack");
if (stack) {
  requestAnimationFrame(() => requestAnimationFrame(() => stack.classList.add("is-settled")));
}

const revealObserver = new IntersectionObserver((entries) => {
  for (const entry of entries) {
    if (entry.isIntersecting) {
      entry.target.classList.add("is-visible");
      revealObserver.unobserve(entry.target);
    }
  }
}, { rootMargin: "0px 0px -8% 0px" });
document.querySelectorAll(".reveal").forEach((el) => revealObserver.observe(el));

const tocLinks = new Map(
  [...document.querySelectorAll(".toc a")].map((a) => [a.getAttribute("href").slice(1), a])
);
const visible = new Set();
const tocObserver = new IntersectionObserver((entries) => {
  for (const entry of entries) {
    if (entry.isIntersecting) visible.add(entry.target.id);
    else visible.delete(entry.target.id);
  }
  const current = [...tocLinks.keys()].find((id) => visible.has(id));
  if (!current) return;
  for (const [id, link] of tocLinks) {
    if (id === current) link.setAttribute("aria-current", "true");
    else link.removeAttribute("aria-current");
  }
}, { rootMargin: "-20% 0px -60% 0px" });
tocLinks.forEach((_, id) => {
  const section = document.getElementById(id);
  if (section) tocObserver.observe(section);
});

const copyIcons =
  '<svg class="ico-copy" viewBox="0 0 16 16" aria-hidden="true"><rect x="5" y="5" width="8.5" height="8.5" rx="1.5" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M10.5 3.5v-.5A1.5 1.5 0 0 0 9 1.5H4A1.5 1.5 0 0 0 2.5 3v5A1.5 1.5 0 0 0 4 9.5h.5" fill="none" stroke="currentColor" stroke-width="1.5"/></svg>' +
  '<svg class="ico-done" viewBox="0 0 16 16" aria-hidden="true"><path d="M3 8.5 6.5 12 13 4.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';
document.querySelectorAll(".code figcaption").forEach((caption) => {
  const button = document.createElement("button");
  button.className = "copy";
  button.type = "button";
  button.innerHTML = `${copyIcons}<span>복사</span>`;
  caption.append(button);
});

document.querySelectorAll(".copy").forEach((button) => {
  const label = button.querySelector("span");
  let timer;
  button.addEventListener("click", async () => {
    const codeEl = button.closest(".code").querySelector("code");
    let copied = false;
    try {
      await navigator.clipboard.writeText(codeEl.innerText);
      copied = true;
    } catch {
      const range = document.createRange();
      range.selectNodeContents(codeEl);
      const selection = getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      copied = document.execCommand("copy");
      selection.removeAllRanges();
    }
    button.dataset.state = copied ? "done" : "error";
    label.textContent = copied ? "복사됨" : "복사 실패";
    clearTimeout(timer);
    timer = setTimeout(() => {
      delete button.dataset.state;
      label.textContent = "복사";
    }, reduceMotion ? 2400 : 1600);
  });
});
