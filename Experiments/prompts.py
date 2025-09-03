cot_prompt = """
Example//
Context: If an individual wakes up early, they will avoid traffic. Conversely, if they get a flat tire, they will miss work. It is known that at least one of the following statements is true: either John wakes up early or he will work. However, the actual veracity of either statement remains ambiguous, as it could be the case that only the first statement is true, only the second statement is true, or both statements are true.
Question: Can we say at least one of the following must always be true? (a) He avoids traffic and (b) He does not get a flat tire"
Let's think step by step.
Thought: The premises are (wakes up early -> avoid traffic), (flat tire -> -work), and (wakes up early | work). The goal is to prove (avoid traffic | -flat tire). I can use the premise (wakes up early | work) to check both possible cases. In the first case, if 'wakes up early' is true, then 'avoid traffic' must also be true, which makes the conclusion (avoid traffic | -flat tire) true. In the second case, if 'work' is true, I must use the contrapositive of the second premise, which is (work -> -flat tire). From this, 'work' being true means '-flat tire' is true, which also makes the conclusion (avoid traffic | -flat tire) true. Since the conclusion holds in both possible scenarios, it is logically guaranteed.
FINAL ANSWER: YES
//end of example

Example//
Context: If P, Q. Conversely, if R, -S. It is known that at least one of the following statements is true: either P or S. However, the actual veracity of either statement remains ambiguous, as it could be the case that only the first statement is true, only the second statement is true, or both statements are true.
Question: Can we say at least one of the following must always be true? (a) -Q and (b) -S"
Let's think step by step.
Thought: The premises are (P -> Q), (R -> -S), and (P | S). The goal is to determine if (-Q | -S) must be true. I will try to find a counterexample where the premises are true but the conclusion is false. For the conclusion (-Q | -S) to be false, both Q and S must be true. Assuming this, we can check the premises: if S is true, then R must be false for the second premise (R -> -S) to hold. If Q is true, we can assume P is true to satisfy the first premise (P -> Q). This assignment also satisfies the third premise, (P | S), since both P and S are true. So, a counterexample exists where P is true, Q is true, S is true, and R is false. Since all premises can be true while the conclusion is false, the conclusion is not guaranteed.
FINAL ANSWER: NO
//end of example
"""

# --- Prompts for ReAct architecture ---

# Step 1: Generate the formal logic action and then STOP.
react_prompt = """
Example//
Context: If an individual wakes up early, they will avoid traffic. Conversely, if they get a flat tire, they will miss work. It is known that at least one of the following statements is true: either John wakes up early or he will work. However, the actual veracity of either statement remains ambiguous, as it could be the case that only the first statement is true, only the second statement is true, or both statements are true.
Question: Can we say at least one of the following must always be true? (a) He avoids traffic and (b) He does not get a flat tire"
Let's think step by step.
Thought: I need to translate the natural language problem into formal logic for Prover9.
First, I will define the general rules with variables.
Mapping predicates:
"wakes up early" -> wakes_early(x)
"avoid traffic" -> avoids_traffic(x)
"get a flat tire" -> gets_flat_tire(x)
"miss work" -> misses_work(x)

General Premises (Axioms):
1. wakes_early(x) -> avoids_traffic(x).
2. gets_flat_tire(x) -> misses_work(x).

Now, I will formalize the specific facts about 'john'.
Mapping specific facts:
"John wakes up early" -> wakes_early(john)
"he will work" -> -misses_work(john)

Specific Premise (for this problem):
3. wakes_early(john) | -misses_work(john).

Goal:
The goal is "avoids_traffic(john) | -gets_flat_tire(john)".

I will now format these premises and the goal for the Prover9 tool.
Action:
BEGIN_PROVER9_INPUT
formulas(usable).
  wakes_early(x) -> avoids_traffic(x).
  gets_flat_tire(x) -> misses_work(x).
end_of_list.
formulas(sos).
  wakes_early(john) | -misses_work(john).
end_of_list.
formulas(goals).
  avoids_traffic(john) | -gets_flat_tire(john).
end_of_list.
END_PROVER9_INPUT
**Observation: PROVED
Thought: The prover result was PROVED. This means the conclusion is logically guaranteed based on the premises.
I will now determine my final answer.
FINAL ANSWER: YES**
//end of example

Example//
Context: If property P holds for an entity, so does property Q. Conversely, if R holds, S does not. It is known that for a specific entity, at least one of the following is true: either P holds or S holds.
Question: For that specific entity, can we say at least one of the following must always be true? (a) Q does not hold and (b) S does not hold.
Let's think step by step.
Thought: I need to translate this symbolic problem into a first-order logic format for Prover9 that is parallel to my other example.
I will use variables for general rules and a constant 'a' for the specific entity.
Mapping predicates:
P -> p(x)
Q -> q(x)
R -> r(x)
S -> s(x)
General Premises (Axioms):
p(x) -> q(x).
r(x) -> -s(x).

Specific Premise (for entity 'a'):
p(a) | s(a).

Goal (for entity 'a'):
The goal is "-q(a) | -s(a)".

I will now format the input for the Prover9 tool.
Action:
BEGIN_PROVER9_INPUT
formulas(usable).
    p(x) -> q(x).
    r(x) -> -s(x).
end_of_list.
formulas(sos).
    p(a) | s(a).
end_of_list.
formulas(goals).
    -q(a) | -s(a).
end_of_list.
END_PROVER9_INPUT
**Observation: FAILED
Thought: The prover result was FAILED. This means a counterexample exists where the premises are true but the goal is false. Therefore, the conclusion is not guaranteed.
I will now determine my final answer.
FINAL ANSWER: NO**
//end of example
"""

# Step 2: Take the generated action, add the observation, and generate the final thought and answer.
react_prompt_template = """{model_step1_output}
Observation: {observation}
Thought: The prover result was {observation}.
I will now determine my final answer.
FINAL ANSWER:"""

react_prompt_template_instruct = """[INST]
{model_step1_output}
OBSERVATION:{observation}
Thought: The prover result was {observation}.
I will now determine my final answer.
FINAL ANSWER:[/INST]"""

