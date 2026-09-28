const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

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
