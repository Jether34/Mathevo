# Math coverage and implementation checklist

This is the working coverage ledger for the requested calculator domains. A
checked item means the listed scope is implemented and has passed its named
app-level validation. `Partial` means the app solves only the stated subset;
it is not a claim that the whole field is implemented.

## Emulator verification boundary

No requested domain is verified as complete end to end. The current Android
integration test covers keypad entry and representative results for five
examples only: GCD, modular exponentiation, finite set union, a tautology, and
a truth table. `Partial` below describes known implementation scope, not full
device-level validation of every operation in that domain. The remaining
operations and all `Not started` domains still need implementation and tests.

## Current implementation slice

- [x] Add a dedicated **Discrete math** calculator mode with visible, tappable
  keys for selected number theory, modular arithmetic, combinatorics, ratios
  and percentages, finite sets, and propositional logic.
- [x] Validate representative key entry and results in the Android app on
  `emulator-5554`; isolated engine tests cover additional operations/errors.
- [ ] Extend this ledger as each later domain gets a solver, mode-specific
  keys, error handling, and device-level test cases.

## Requested domain checklist

| Domain | Status | Current scope or remaining work |
| --- | --- | --- |
| Discrete math calculator mode | Partial | Keys and tested operations: `gcd`, `lcm`, `isPrime`, `factors`, `mod`, `modPow`, `modInverse`, `nCr`, `nPr`, `ratio`, `percent`, finite set operations, truth tables, tautology, satisfiability, and contradiction. Verified examples are in `test/discrete_math_test.dart` and `integration_test/discrete_math_e2e_test.dart`. This is not full coverage of any broad field below. |
| Mathematical Logic | Partial | Propositional truth evaluation and truth tables are in the current slice; predicate logic and proof systems remain. |
| Propositional Logic | Partial | Truth tables, tautology, satisfiability, contradiction; richer normal forms and proof tools remain. |
| Predicate Calculus | Not started | Quantifiers, predicates, domains, and variable binding. |
| Proof Theory | Not started | Formal proof construction, checking, and proof rules. |
| Set Theory | Partial | Finite union, intersection, difference, and symmetric difference; relations, power sets, and infinite sets remain. |
| Transfinite Numbers | Not started | Ordinals, cardinals, and transfinite arithmetic. |
| Category Theory | Not started | Categories, functors, natural transformations, and diagrams. |
| Arithmetic | Partial | Exact rational arithmetic and standard numeric expressions; broader integer and decimal workflows remain. |
| Fraction Operations | Partial | Exact rational arithmetic; mixed numbers, fraction entry templates, and broader simplification workflows remain. |
| Percentages and Ratios | Partial | Percentage-of and ratio-reduction commands in the current slice; change, markup, and proportion workflows remain. |
| Number Theory | Partial | GCD, LCM, primality, bounded factorization, modular operations; deeper theorems and algorithms remain. |
| Prime Numbers | Partial | Primality checks and factorization up to the documented bound; prime generation and larger-scale algorithms remain. |
| Modular Arithmetic | Partial | Remainder, modular power, and modular inverse; congruence solving and CRT remain. |
| Cryptographic Mathematics | Partial | Modular primitives only; vetted cryptographic protocols, key generation, and security properties are not implemented. |
| Elementary Algebra | Partial | Linear and quadratic equation solving; inequalities and broader symbolic manipulation remain. |
| Systems of Equations | Partial | Two-variable linear systems; larger and nonlinear systems remain. |
| Polynomials and Factoring | Partial | Degree-two equation roots; general polynomial arithmetic, factoring, and root isolation remain. |
| Linear Algebra | Not started | Matrices, vectors, decompositions, and numerical stability. |
| Vector Spaces | Not started | Basis, dimension, span, and subspaces. |
| Matrices and Determinants | Not started | Matrix entry, arithmetic, determinant, inverse, and decompositions. |
| Linear Transformations | Not started | Matrix mappings, kernels, images, and coordinate changes. |
| Abstract Algebra | Not started | Algebraic structures and operations. |
| Group Theory | Not started | Groups, subgroups, cyclic groups, and symmetry calculations. |
| Ring Theory | Not started | Ring operations, ideals, and quotient rings. |
| Field Theory | Not started | Field extensions and finite fields. |
| Galois Theory | Not started | Field automorphisms and polynomial solvability. |
| Euclidean Geometry | Partial | Common 2D and 3D measurement formulas; construction and theorem workflows remain. |
| Planar Geometry (2D) | Partial | Common circle, rectangle, triangle, and parallelogram calculations; broader constructions remain. |
| Solid Geometry (3D) | Partial | Common cylinder, cone, and sphere measurements and visualizations; broader solids and validated measurements remain. |
| Non-Euclidean Geometry | Not started | Alternative geometric models and distance rules. |
| Hyperbolic Geometry | Not started | Hyperbolic models, distances, and constructions. |
| Elliptic Geometry | Not started | Elliptic models, distances, and constructions. |
| Trigonometry | Partial | Standard ratios and right-triangle visualization; identities and equation solving remain. |
| Circular Trigonometry | Partial | DEG/RAD basic circular functions; broader unit-circle workflows remain. |
| Hyperbolic Trigonometry | Partial | Hyperbolic and inverse hyperbolic evaluation and graph input keys are available; identities and hyperbolic geometry remain. |
| Analytic Geometry | Partial | Basic coordinate graphing; distances, loci, and transformations remain. |
| Coordinate Geometry | Partial | Single-variable graphing and selected geometry; broader coordinate tools remain. |
| Conic Sections | Not started | Parabolas, ellipses, and hyperbolas with parameter tools. |
| Differential Geometry | Not started | Curves, surfaces, curvature, and local coordinates. |
| Manifolds and Tensors | Not started | Charts, tensor operations, and coordinate transformations. |
| Geometric Topology | Not started | Geometric structures and topology operations. |
| General Topology | Not started | Topological spaces, continuity, and compactness. |
| Algebraic Topology | Not started | Homology, homotopy, and related invariants. |
| Knot Theory | Not started | Knot representation and invariants. |
| Differential Calculus | Partial | Selected symbolic derivatives; broader functions and multivariable rules remain. |
| Rates of Change | Partial | Derivative tools for the supported expression grammar. |
| Limits and Continuity | Not started | Limit evaluation and continuity checks. |
| Optimization and Extremums | Not started | Local/global extrema and constrained optimization. |
| Integral Calculus | Partial | Selected antiderivatives and numerical definite integrals. |
| Antiderivatives | Partial | Limited polynomial and basic trigonometric rules. |
| Definite and Indefinite Integrals | Partial | Limited symbolic antiderivatives and adaptive numerical definite integration. |
| Area and Volume Accumulation | Partial | Selected geometric formulas and definite integral visualization. |
| Multivariable Calculus | Not started | Multiple variables, domains, and multivariable operations. |
| Partial Derivatives | Not started | Partial differentiation and gradient workflows. |
| Multiple Integrals | Not started | Double and triple integration. |
| Vector Calculus | Not started | Vector fields and vector-valued operations. |
| Gradient, Divergence, and Curl | Not started | Differential operators on scalar and vector fields. |
| Line and Surface Integrals | Not started | Curve/surface parameterization and integration. |
| Real Analysis | Not started | Rigorous real limits, sequences, and convergence. |
| Complex Analysis | Not started | Complex arithmetic and analytic functions. |
| Infinite Series and Sequences | Not started | Sequence terms, convergence, and series evaluation. |
| Measure Theory | Not started | Measurable spaces, measures, and integration foundations. |
| Combinatorics | Partial | Permutations and combinations; recurrence and advanced counting remain. |
| Permutations and Combinations | Partial | Exact `nPr` and `nCr` commands with bounded input. |
| Counting Principles | Partial | Basic selection and arrangement counts; inclusion-exclusion and recurrence tools remain. |
| Graph Theory | Not started | Graph input, traversal, paths, and invariants. |
| Network Optimization | Not started | Shortest paths, flows, and matching. |
| Tree Structures | Not started | Tree operations, traversal, and counting. |
| Order Theory | Not started | Partial orders, lattices, and order operations. |
| Boolean Algebra | Partial | Propositional truth operations; Boolean simplification and circuit tools remain. |
| Probability Theory | Partial | Event probability, complements, odds, one binomial outcome, combinations, and permutations; distributions, conditional/multivariate probability, and inference remain. |
| Random Variables | Not started | Discrete/continuous distributions and expectations. |
| Stochastic Processes | Not started | Markov chains and stochastic process calculations. |
| Descriptive Statistics | Partial | Mean, median, mode, range, sum, count, quartiles, and population/sample variance and standard deviation for entered numeric lists. |
| Inferential Statistics | Not started | Confidence intervals and inference procedures. |
| Hypothesis Testing | Not started | Test statistics, p-values, and assumptions. |
| Regression Analysis | Not started | Linear and nonlinear regression workflows. |
| Ordinary Differential Equations (ODEs) | Not started | Symbolic/numeric ODE solving and initial conditions. |
| Partial Differential Equations (PDEs) | Not started | PDE models and numerical solvers. |
| Dynamical Systems and Chaos Theory | Not started | Iteration, stability, and chaos diagnostics. |
| Numerical Analysis | Partial | Adaptive Simpson integration and sampled graphing; wider solver coverage remains. |
| Error Analysis | Not started | Propagation, conditioning, and numerical error bounds. |
| Root-Finding Algorithms | Not started | Bisection, Newton, secant, and convergence reporting. |
| Numerical Integration and Differentiation | Partial | Adaptive Simpson definite integration; numerical differentiation remains. |
| Computational Mathematics | Partial | Offline expression evaluation and selected numerical routines. |
| Algorithm Complexity Math | Not started | Complexity functions and asymptotic comparisons. |
| Automata Theory | Not started | Finite automata, regular expressions, and language operations. |
| Optimization Theory | Not started | General optimization models and algorithms. |
| Linear Programming | Not started | LP model entry and optimization. |
| Non-linear Optimization | Not started | Nonlinear objectives and constraints. |
| Game Theory | Not started | Payoff matrices, equilibria, and solution concepts. |
| Operations Research | Not started | Decision models, scheduling, and optimization. |
| Actuarial Science | Not started | Survival, loss, and actuarial models. |
| Financial Mathematics | Not started | Interest, annuities, bonds, and cash-flow analysis. |
| Mathematical Physics | Partial | Constant-speed distance, velocity, and time formulas; unit conversion and broader physical models remain. |
| Fluid Dynamics Math | Not started | Fluid equations and numerical models. |
| Relativity and Quantum Mathematics | Not started | Tensor/quantum state calculations and validated conventions. |
| Mathematical Biology | Not started | Mathematical models for biological systems. |
| Population Modeling | Not started | Population growth and interaction models. |
| Biostatistics | Not started | Study designs and biostatistical inference. |
| Information Theory | Not started | Entropy and information measures. |
| Data Compression Math | Not started | Coding/compression metrics and algorithms. |
| Error-Correcting Codes | Not started | Finite-field code construction and decoding. |

## Key and result standard for each completed area

For an area to move to complete, it needs a dedicated or clearly contextual
key set, accepted input syntax, domain/range validation, accurate result
formatting, meaningful errors, unit coverage, and a representative end-to-end
Android interaction. A plotted result is a separate requirement where the
domain needs visualization. A shared `=` key or generic expression parser by
itself does not count as a completed branch.
