# QA Principles

**What humans do better than computers: context, creativity, and subjective evaluation.**

## What Cannot Be Fully Automated

### 1. Requirements Validation

**Are we building the right thing?**

This is fundamentally a human activity because it requires:
- Understanding user needs (often unstated or evolving)
- Evaluating trade-offs (features vs. complexity, speed vs. quality)
- Contextual judgment (business goals, market conditions)

**Human QA Activities**:
- **User story validation**: Do acceptance criteria actually satisfy user needs?
- **Scope review**: Are we solving the right problem or just the stated one?
- **Prioritization**: Which features deliver the most value?
- **Trade-off evaluation**: Should we ship now with tech debt, or delay for quality?

**Example**:
```
Requirement: "Add user authentication"

❌ Automated test: Can verify authentication works
✅ Human QA: Should we require 2FA? How long should sessions last?
            What's the password reset flow? How do we handle account lockout?
            These require business and UX judgment.
```

### 2. User Experience (UX) Evaluation

**Does it feel right?**

Automation can check functional correctness, but can't evaluate subjective quality.

**Human QA Activities**:
- **Usability**: Is the flow intuitive? Are labels clear?
- **Aesthetics**: Does the design feel polished or janky?
- **Accessibility**: Can users with disabilities actually use this?
- **Consistency**: Does this match the rest of the product?
- **Emotional response**: Does this feel trustworthy/professional/delightful?

**Example**:
```
Automated test: ✅ Button click triggers correct API call
Human QA: ❌ Button is too small, label is confusing, feels unresponsive
```

**Tools That Help (But Don't Replace Humans)**:
- Lighthouse (accessibility scores, performance metrics)
- Axe DevTools (automated accessibility checks)
- Visual regression testing (screenshot diffs)

These catch *some* issues, but can't replace human judgment about "good" UX.

### 3. Exploratory Testing

**What happens if...?**

Humans are creative at finding edge cases automation didn't anticipate.

**Human QA Activities**:
- **Uncovering unknown unknowns**: Testing scenarios not in requirements
- **Adversarial thinking**: What if users do something unexpected?
- **Context switching**: Using the product in different environments/devices
- **Error message quality**: Are errors helpful or cryptic?

**Example**:
```
Automated test: Create user with valid email
Human QA: What if I paste emoji in the name field? 🤔
         What if I hit submit twice rapidly?
         What if I'm on a slow connection?
         What if I press back after submitting?
```

### 4. Risk Assessment

**What are the consequences of failure?**

Humans evaluate severity, likelihood, and business impact in ways algorithms can't.

**Human QA Activities**:
- **Severity classification**: Is this bug critical or cosmetic?
- **Impact analysis**: How many users are affected? What's the business cost?
- **Risk vs. reward**: Should we ship with this known issue?
- **Mitigation strategy**: Do we need a rollback plan? Feature flag?

**Example**:
```
Bug: Typo in help text
Automated system: ❌ Can detect typo
Human QA: ✅ Evaluate: Low severity, ship it, fix in next release

Bug: Payment processing fails for $0.00 orders
Automated system: ❌ Can detect failure
Human QA: ✅ Evaluate: High severity, blocks edge case, what's frequency?
                      Should we block $0 orders or fix the bug?
```

### 5. Compliance and Governance

**Does this meet legal/regulatory requirements?**

Often requires domain expertise and legal interpretation.

**Human QA Activities**:
- **Regulatory compliance**: GDPR, HIPAA, SOC2, PCI-DSS
- **Legal review**: Terms of service, privacy policy consistency
- **Ethical considerations**: Bias in ML models, dark patterns
- **Audit trails**: Are we logging what we legally must?

**Example**:
```
Automated test: ✅ Deletes user data when requested
Human QA: ✅ Verify GDPR compliance:
            - Are backups also deleted?
            - Is data deleted from third-party integrations?
            - Is deletion logged for audit?
```
