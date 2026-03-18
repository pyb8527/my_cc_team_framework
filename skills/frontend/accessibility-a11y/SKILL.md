---
name: accessibility-a11y
description: Web accessibility (WCAG 2.1 AA) best practices for React/Next.js including semantic HTML, ARIA patterns, keyboard navigation, focus management, color contrast, and screen reader support.
---

# Web Accessibility (a11y) Best Practices

## WCAG 2.1 AA — Core Principles (POUR)

```
Perceivable   — content visible/audible to all users
Operable      — UI usable with keyboard, no seizure-inducing content
Understandable— predictable, clear language, error recovery
Robust        — works across assistive technologies
```

## Semantic HTML (Foundation)

```tsx
// ❌ Div soup
<div onClick={handleClick} class="button">Submit</div>
<div class="nav"><div>Home</div><div>About</div></div>

// ✅ Semantic elements
<button onClick={handleClick} type="submit">Submit</button>
<nav aria-label="Main navigation">
  <ul>
    <li><a href="/">Home</a></li>
    <li><a href="/about">About</a></li>
  </ul>
</nav>

// Page landmark structure
<header>
  <nav aria-label="Primary">...</nav>
</header>
<main id="main-content">   {/* Skip link target */}
  <h1>Page Title</h1>
  <section aria-labelledby="section-heading">
    <h2 id="section-heading">Section</h2>
  </section>
</main>
<footer>...</footer>
```

## Skip Navigation

```tsx
// Always first element in <body>
export function SkipNav() {
  return (
    <a
      href="#main-content"
      className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-white focus:text-black"
    >
      본문으로 바로가기
    </a>
  );
}
```

## ARIA Patterns

```tsx
// Buttons with icon only — must have label
<button aria-label="메뉴 닫기">
  <XIcon aria-hidden="true" />
</button>

// Form fields — always associate label
<label htmlFor="email">이메일</label>
<input
  id="email"
  type="email"
  aria-required="true"
  aria-invalid={!!errors.email}
  aria-describedby={errors.email ? "email-error" : undefined}
/>
{errors.email && (
  <p id="email-error" role="alert" aria-live="polite">
    {errors.email.message}
  </p>
)}

// Loading state
<button aria-busy={isLoading} disabled={isLoading}>
  {isLoading ? '저장 중...' : '저장'}
</button>

// Modal dialog
<div
  role="dialog"
  aria-modal="true"
  aria-labelledby="dialog-title"
  aria-describedby="dialog-description"
>
  <h2 id="dialog-title">확인</h2>
  <p id="dialog-description">정말 삭제하시겠습니까?</p>
</div>

// Live regions for dynamic content
<div aria-live="polite" aria-atomic="true">
  {statusMessage}  {/* Screen reader announces changes */}
</div>
<div aria-live="assertive">
  {errorMessage}   {/* Interrupts screen reader immediately */}
</div>
```

## Keyboard Navigation

```tsx
// Focus trap in modals
import { useEffect, useRef } from 'react';

function Modal({ isOpen, onClose }: ModalProps) {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      previousFocusRef.current = document.activeElement as HTMLElement;
      modalRef.current?.focus();
    } else {
      previousFocusRef.current?.focus();  // Restore focus on close
    }
  }, [isOpen]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') onClose();
    if (e.key === 'Tab') trapFocus(e, modalRef.current!);
  };

  return (
    <div ref={modalRef} tabIndex={-1} onKeyDown={handleKeyDown} role="dialog" aria-modal="true">
      ...
    </div>
  );
}

function trapFocus(e: React.KeyboardEvent, container: HTMLElement) {
  const focusable = container.querySelectorAll<HTMLElement>(
    'a, button:not([disabled]), input:not([disabled]), select, textarea, [tabindex]:not([tabindex="-1"])'
  );
  const first = focusable[0];
  const last = focusable[focusable.length - 1];
  if (e.shiftKey && document.activeElement === first) {
    e.preventDefault();
    last.focus();
  } else if (!e.shiftKey && document.activeElement === last) {
    e.preventDefault();
    first.focus();
  }
}
```

## Color & Contrast

```
WCAG AA Requirements:
  Normal text (< 18pt):  contrast ratio ≥ 4.5:1
  Large text (≥ 18pt):   contrast ratio ≥ 3:1
  UI components:          contrast ratio ≥ 3:1

Tools:
  - https://webaim.org/resources/contrastchecker/
  - Chrome DevTools → Accessibility pane
  - axe DevTools browser extension
```

```css
/* Never rely on color alone */
/* ❌ Red = error, green = success */
/* ✅ Add icon + text label */

:focus-visible {
  outline: 3px solid #005fcc;   /* High contrast focus ring */
  outline-offset: 2px;
}

/* Remove default only when replacing with custom */
:focus:not(:focus-visible) {
  outline: none;
}
```

## Images & Media

```tsx
// Decorative images — empty alt
<img src="decoration.svg" alt="" aria-hidden="true" />

// Informative images — descriptive alt
<img src="chart.png" alt="2024년 월별 매출: 1월 1억, 2월 1.2억..." />

// Complex images — use figcaption or aria-describedby
<figure>
  <img src="complex-diagram.png" alt="시스템 아키텍처 다이어그램" aria-describedby="diagram-desc" />
  <figcaption id="diagram-desc">
    클라이언트가 API Gateway를 통해 마이크로서비스와 통신하는 구조...
  </figcaption>
</figure>

// Videos — captions required
<video controls>
  <source src="video.mp4" type="video/mp4" />
  <track kind="captions" src="captions-ko.vtt" srclang="ko" label="한국어" default />
</video>
```

## React Accessibility Hooks

```tsx
// useId for unique IDs (React 18+)
function FormField({ label, error }: Props) {
  const id = useId();
  const errorId = `${id}-error`;
  return (
    <>
      <label htmlFor={id}>{label}</label>
      <input id={id} aria-describedby={error ? errorId : undefined} />
      {error && <p id={errorId} role="alert">{error}</p>}
    </>
  );
}
```

## Automated Testing

```tsx
// jest + @testing-library/jest-dom + jest-axe
import { axe, toHaveNoViolations } from 'jest-axe';
expect.extend(toHaveNoViolations);

test('has no accessibility violations', async () => {
  const { container } = render(<LoginForm />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

## Checklist (WCAG 2.1 AA)

- [ ] Skip navigation link present
- [ ] All images have descriptive `alt` text (decorative → `alt=""`)
- [ ] Form fields have associated `<label>`
- [ ] Error messages linked via `aria-describedby`
- [ ] Color contrast ≥ 4.5:1 for body text
- [ ] Focus visible on all interactive elements
- [ ] Modals trap focus and restore on close
- [ ] Dynamic content uses `aria-live` regions
- [ ] Page has single `<h1>`, logical heading hierarchy
- [ ] Keyboard navigation works without mouse
- [ ] Videos have captions/transcripts
- [ ] `lang` attribute set on `<html>`
