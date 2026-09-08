# EARS by Example

A companion to [Overview](overview.md) § EARS: The Requirements Format.
That section defines the six templates; this one shows what they look
like in practice, what does *not* qualify, and how requirements are
categorized once they are written.

---

## The six patterns

| Pattern | Template | When to use |
|---|---|---|
| **Ubiquitous** | The \<system\> shall \<response\> | Always-active requirements |
| **Event-driven** | When \<trigger\>, the \<system\> shall \<response\> | Triggered by a discrete event |
| **State-driven** | While \<state\>, the \<system\> shall \<response\> | Active throughout a state |
| **Optional feature** | Where \<feature\>, the \<system\> shall \<response\> | Only when a feature is present |
| **Unwanted behavior** | If \<trigger\>, then the \<system\> shall \<response\> | Handling errors and failures |
| **Complex** | Combination of the above | Multiple conditions |

---

## One requirement per pattern — ProtoBot's own domain

| Pattern | Example |
|---|---|
| **Ubiquitous** | The Specification Toolkit shall assign every requirement a stable identifier that persists across revisions. |
| **Event-driven** | When a change set is approved, the WMS Adapter shall materialize a build work item at the approved specification commit. |
| **State-driven** | While a build work item is in `waiting`, the Job Site shall not claim it. |
| **Optional feature** | Where the deployment is configured for multi-player mode, the Drafting Table shall submit change sets as pull requests against main. |
| **Unwanted behavior** | If a requirement statement matches no EARS pattern, then `ears-manager check` shall reject the change set and name the offending requirement. |
| **Complex** | While a build work item is claimed, when an Inspector reports a defect, the Job Site shall return the item to Building with the defect attached. |

The grammar is indifferent to what kind of thing a requirement
describes. All of these are valid EARS, and none of them is functional
in the classic sense:

- The API shall use TLS 1.3 or later for all external connections.
  *(security)*
- When a client submits valid credentials, the authentication service
  shall return a JWT token within 500ms. *(performance)*
- The web UI shall use PatternFly components. *(environmental — imposed
  from outside, not chosen by the Building phase)*

And what is *not* a requirement, for three different reasons:

- ✗ *The `SpecStore` class shall index requirements in a hash map.*
  Valid grammar, wrong layer — internal structure belongs to Building,
  not to the Schematic.
- ✗ *The system shall be user-friendly.* Valid grammar, but nothing can
  verify it.
- ✗ *The system should handle errors gracefully.* Not a pattern at all:
  no `shall`, no trigger, no verifiable response.

---

## A real-world example: an e-commerce app

A small storefront — product catalog, cart, checkout, payment, order
history — specified the way ProtoBot would specify it. Three external
interfaces (`storefront-api`, `web-ui`, `payment-adapter`) plus
project-wide constraints.

### Catalog and cart

| Pattern | Requirement |
|---|---|
| **Ubiquitous** | The storefront API shall expose every product price in minor currency units together with an ISO 4217 currency code. |
| **Event-driven** | When a shopper adds a product to the cart, the storefront API shall return the updated cart with line totals and a grand total. |
| **State-driven** | While a product is out of stock, the storefront API shall present it as unpurchasable and reject any request to add it to a cart. |
| **Unwanted behavior** | If a shopper requests a quantity greater than the available stock, then the storefront API shall reject the request and return the currently available quantity. |
| **Optional feature** | Where guest checkout is enabled, the web UI shall allow a shopper to reach the payment step without creating an account. |

### Checkout and payment

| Pattern | Requirement |
|---|---|
| **Event-driven** | When a shopper submits an order, the storefront API shall reserve stock for every line item before requesting payment authorization. |
| **Event-driven** | When the payment provider authorizes a charge, the storefront API shall transition the order to `confirmed` and send a confirmation email within 60 seconds. |
| **Unwanted behavior** | If payment authorization fails, then the storefront API shall release the reserved stock and return the order to `cart` without charging the shopper. |
| **Unwanted behavior** | If the payment provider does not respond within 30 seconds, then the payment adapter shall abandon the request and report the order as `payment-pending`. |
| **State-driven** | While an order is in `payment-pending`, the storefront API shall reject any second submission of the same order. |
| **Complex** | While an order is in `confirmed`, when a shopper requests cancellation and the order has not shipped, the storefront API shall cancel the order and issue a full refund. |

### Applied to the whole project

| Pattern | Requirement | Why it is here |
|---|---|---|
| **Ubiquitous** | The storefront API shall serve all traffic over TLS 1.3 or later. | Security |
| **Ubiquitous** | The storefront API shall return the product listing page for 1,000 products within 300ms at the 95th percentile. | Performance |
| **Ubiquitous** | The system shall not store card numbers, CVV codes, or full magnetic-stripe data. | Compliance (PCI DSS) |
| **Ubiquitous** | The web UI shall meet WCAG 2.1 Level AA for the catalog, cart, and checkout flows. | Accessibility |
| **Ubiquitous** | The web UI shall be built with PatternFly components. | Environmental — mandated from outside |
| **Optional feature** | Where a marketing consent banner is required by the deployment region, the web UI shall block analytics scripts until consent is given. | Regional/legal variation |

Note that these are ordinary EARS sentences. Nothing in the grammar
marks them as "non-functional"; they are told apart from the catalog
requirements above by their **metadata**, not by their wording.

### The same requirement, with its metadata

Requirement records carry the sentence plus the fields that make it
machine-queryable ([User Interaction
Flow](user-interaction-flow.md#phase-2-dimensioning)):

```json
{
  "id": "REQ-CHECKOUT-004",
  "applies_to": {
    "interfaces": ["storefront-api", "payment-adapter"],
    "scopes": ["checkout", "payments"]
  },
  "verification": {
    "mode": "isolated-interface"
  },
  "type": "unwanted-behavior",
  "text": "If payment authorization fails, then the storefront API shall release the reserved stock and return the order to `cart` without charging the shopper.",
  "provenance": "user-authored",
  "created": "2026-08-30T09:15:00Z"
}
```

### What did *not* become a requirement

The same storefront, and the things a reviewer would push back on:

- ✗ *The order service shall publish an `OrderConfirmed` event to
  Kafka.* Internal decomposition — the Building phase chooses how the
  confirmation email gets sent, unless the message bus is imposed from
  outside, in which case it is an environmental requirement instead.
- ✗ *The `CartRepository` shall cache carts in Redis for 30 minutes.*
  Internal data flow and a library choice.
- ✗ *Checkout shall be fast.* Unverifiable; the 300ms/p95 requirement
  above is the version that survives.
- ✗ *The system should support discount codes.* Not a pattern — `should`
  is not `shall`, and there is no response to verify. Rewrite as: *Where
  a discount code is applied to a cart, the storefront API shall reduce
  the grand total by the code's value and record the code on the order.*

---

## How EARS requirements are categorized

The EARS pattern is a sentence shape, not a taxonomy — it tells you
nothing about whether a requirement is functional, non-functional,
business, or technical. Classification comes from the requirement's
metadata instead:

| Axis | Field | Values |
|---|---|---|
| **Scope** | `applies_to` | one or more stable interface IDs, or an explicit project-wide/environmental selector |
| **Verification** | `verification.mode` | `isolated-interface` (default) or `implementation-aware`, which requires a rationale |
| **Sentence shape** | `type` | the six templates above |

By this axis, the checkout requirements are scoped to
`storefront-api`/`payment-adapter`, while TLS, latency, PCI, WCAG, and
PatternFly are project-wide — that is the whole of what separates them.

Technical constraints are in scope when they are imposed from outside (a
mandated component library, a base image, a language) and are captured
as environmental requirements. Technical *internals* are deliberately
excluded — see the boundary table in [User Interaction
Flow](user-interaction-flow.md#what-belongs-in-the-architecture).

`ears-manager check` enforces three things: the statement matches one of
the six patterns; at least one applicability selector is present
alongside the pattern field; and `verification.mode` is declared, with
`implementation-aware` requiring a rationale. Missing fields are
rejected. See [Components](components.md).

---

**References:**

- [Alistair Mavin's EARS page](https://alistairmavin.com/ears/)
- Mavin, A., Wilkinson, P., Harwood, A. & Novak, M. (2009). "Easy
  Approach to Requirements Syntax (EARS)." *Proceedings of the 17th
  IEEE International Requirements Engineering Conference*, pp.
  317–322. DOI: 10.1109/RE.2009.9
