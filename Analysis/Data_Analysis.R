# Load Essential Libraries
require(ggplot2)

# Import and load dataset using csv in directory
df = LLM_Logic_Results

# Print column names and inspect data structure.
print(names(df))
head(df)

# Drop notes column as this is not influential to analysis
new_df <- subset(df, select = -c(Combined_Analysis, Notes))


# Manually simplify names for consistency
names(new_df) <- c("test_case_id", "llm_name", "prompt_technique", "final_answer_outcome", 
               "reasoning_outcome", "ground_truth", 
               "react_observation")

# Create flag columns for quantitative analysis
  # one for correct answer
  # one for correct reasoning
  # one for lucky guesses (correct answer without correct reasoning)
  # one for fully correct answers (correct answer with correct reasoning)
new_df$correctness_flag <- ifelse(new_df$final_answer_outcome == new_df$ground_truth, 1, 0)
new_df$reasoning_correct_flag <- ifelse(new_df$reasoning_outcome == "Yes", 1, 0)
new_df$correct_answer_incorrect_reasoning_flag <- ifelse(
  new_df$prompt_technique != "Basic" & new_df$correctness_flag == 1 & new_df$reasoning_correct_flag == 0, 
  1, 
  0
)
new_df$fully_correct_flag <- ifelse(
  new_df$prompt_technique != "Basic" & new_df$correctness_flag == 1 & new_df$reasoning_correct_flag == 1,
  1,
  0
)

# Calculate key metrics
#-------------------
# Analysis 1 & 2: Overall Accuracy Performance
  # One analysis based on LLM Type
  # One analysis based on Prompt Type
llm_performance <- aggregate(correctness_flag ~ llm_name, data = new_df, FUN = mean)
technique_performance <- aggregate(correctness_flag ~ prompt_technique, data = new_df, FUN = mean)

# Print results
print("Overall Accuracy by LLM")
print(llm_performance)
# visualize
ggplot(llm_performance, aes(x = llm_name, y = correctness_flag, fill = llm_name)) +
  geom_col(width = 0.6) +
  labs(title = "Overall LLM Performance", x = "Model", y = "Correctness") +
  theme(
    legend.position = "none",
    plot.title = element_text(hjust = 0.5)  # centers the title
  )

print("Overall Accuracy by Prompt Technique")
print(technique_performance)
# visualize
ggplot(technique_performance, aes(x = prompt_technique, y = correctness_flag, fill = prompt_technique)) +
  geom_col(width = 0.6) +
  labs(title = "Overall Prompt Technique Performance", x = "Prompt Technique", y = "Correctness") +
  theme(
    legend.position = "none",
    plot.title = element_text(hjust = 0.5)  # centers the title
  )

# Analysis 3: Count of Inconclusive Answers by Model and Prompt
inconclusive_counts <- subset(new_df, final_answer_outcome == "Inconclusive")

inconclusive_summary <- aggregate(
  test_case_id ~ llm_name + prompt_technique,
  data = inconclusive_counts,
  FUN = length
)
names(inconclusive_summary)[3] <- "inconclusive_count"

print("Count of Inconclusive Answers by LLM and Prompt Technique")
print(inconclusive_summary)

# Visualization
ggplot(inconclusive_summary, aes(x = prompt_technique, y = inconclusive_count, fill = llm_name)) +
  geom_col(position = "dodge", width = 0.6) +
  labs(
    title = "Inconclusive Answer Counts by Model and Prompt",
    x = "Prompt Technique",
    y = "Number of Inconclusive Answers",
    fill = "Model"
  ) +
  theme(
    plot.title = element_text(hjust = 0.5)  # centers title
  )

# Analysis 4: Accuracy not including Inconclusive Answers
# Filter out Inconclusive final answers
answer_df <- subset(new_df, final_answer_outcome %in% c("Yes", "No"))

# Recompute correctness on filtered data
answer_df$correctness_flag <- ifelse(answer_df$final_answer_outcome == answer_df$ground_truth, 1, 0)

# Ensure consistent factor levels
prompt_levels <- unique(new_df$prompt_technique)
model_levels  <- unique(new_df$llm_name)
answer_df$prompt_technique <- factor(answer_df$prompt_technique, levels = prompt_levels)
answer_df$llm_name         <- factor(answer_df$llm_name, levels = model_levels)

# Aggregate: accuracy (mean) and count (n) by model + prompt
agg_acc <- aggregate(correctness_flag ~ llm_name + prompt_technique, data = answer_df, FUN = mean)
names(agg_acc)[3] <- "accuracy"

agg_n <- aggregate(correctness_flag ~ llm_name + prompt_technique, data = answer_df, FUN = length)
names(agg_n)[3] <- "n_answers"

# Merge with full grid to include zero-observation combos
all_combos <- expand.grid(llm_name = model_levels, prompt_technique = prompt_levels, stringsAsFactors = FALSE)
acc_summary <- merge(all_combos, agg_acc, by = c("llm_name", "prompt_technique"), all.x = TRUE)
acc_summary <- merge(acc_summary, agg_n, by = c("llm_name", "prompt_technique"), all.x = TRUE)
acc_summary$n_answers[is.na(acc_summary$n_answers)] <- 0

# Keep NA for accuracy if no answers, so we don't plot misleading bars
plot_df <- acc_summary[acc_summary$n_answers > 0, ]

# 6) Plot grouped bars
ggplot(plot_df, aes(x = prompt_technique, y = accuracy, fill = llm_name)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.6) +
  geom_text(aes(label = paste0(round(accuracy * 100, 1), "%\n(n=", n_answers, ")")),
            position = position_dodge(width = 0.75),
            vjust = -0.5, size = 3) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.1),
                     labels = function(x) paste0(x * 100, "%")) +
  labs(
    title = "Accuracy by Prompt and Model (Excluding Inconclusives)",
    x = "Prompt Technique",
    y = "Accuracy",
    fill = "Model"
  ) +
  theme(
    plot.title = element_text(hjust = 0.5),
    axis.text.x = element_text(angle = 25, hjust = 1)
  )


# Analysis 4: Model x Prompt Accuracy Performance
model_by_prompt_performance <- aggregate(correctness_flag ~ llm_name + prompt_technique, data = new_df, FUN = mean)
names(model_by_prompt_performance)[3] <- "accuracy"
print("Overall Accuracy by LLM and Prompt Technique")
print(model_by_prompt_performance)

# Analysis 5: Reasoning Analysis (for CoT and ReAct prompts)
  # subset of the data containing only these prompts.
reasoning_df <- new_df[new_df$prompt_technique != "Basic", ]
print(head(reasoning_df))

# Analysis 6: Performance by Ground Truth (Yes vs No)
ground_truth_performance <- aggregate(correctness_flag ~ llm_name + prompt_technique + ground_truth, data = new_df, FUN = mean)
names(ground_truth_performance)[4] <- "accuracy"
print("Accuracy by LLM, Prompt Technique, and Ground Truth")
print(ground_truth_performance)

# Analysis 7: Performance by Question Type
# Extract the last digit of the test_case_id to create a question_type column
new_df$question_type <- substr(new_df$test_case_id, nchar(as.character(new_df$test_case_id)), nchar(as.character(new_df$test_case_id)))
question_type_performance <- aggregate(correctness_flag ~ llm_name + prompt_technique + question_type, data = new_df, FUN = mean)
names(question_type_performance)[4] <- "accuracy"
print("Accuracy by LLM, Prompt Technique, and Question Type")
print(question_type_performance)

# Analysis 8: Reasoning Performance by Ground Truth (ReAct Only)
react_df <- new_df[new_df$prompt_technique == "ReAct", ]
reasoning_by_truth <- aggregate(reasoning_correct_flag ~ llm_name + ground_truth, data = react_df, FUN = mean)
names(reasoning_by_truth)[3] <- "reasoning_accuracy"
print("Reasoning Accuracy for ReAct Prompts by LLM and Ground Truth")
print(reasoning_by_truth)

# Analysis 9: Reasoning Performance by Question Type (ReAct Only)
react_df$question_type <- substr(react_df$test_case_id, nchar(as.character(react_df$test_case_id)), nchar(as.character(react_df$test_case_id)))
reasoning_by_q_type <- aggregate(reasoning_correct_flag ~ llm_name + question_type, data = react_df, FUN = mean)
names(reasoning_by_q_type)[3] <- "reasoning_accuracy"
print("Reasoning Accuracy for ReAct Prompts by LLM and Question Type")
print(reasoning_by_q_type)

# Aggregate reasoning accuracy by LLM, prompt technique, and question type
reasoning_by_question_type_react <- aggregate(reasoning_correct_flag ~ llm_name + question_type,
                                              data = react_df, FUN = mean)
# Rename the aggregated column for clarity
names(reasoning_by_question_type)[4] <- "reasoning_accuracy"

# Print the results
print("Reasoning Accuracy by LLM and Question Type (ReAct Only)")
print(reasoning_by_question_type_react)

# Calculate the rate for each reasoning-related flag
reasoning_accuracy <- aggregate(reasoning_correct_flag ~ llm_name + prompt_technique, data = reasoning_df, FUN = mean)
lucky_guess_rate <- aggregate(correct_answer_incorrect_reasoning_flag ~ llm_name + prompt_technique, data = reasoning_df, FUN = mean)
fully_correct_rate <- aggregate(fully_correct_flag ~ llm_name + prompt_technique, data = reasoning_df, FUN = mean)

# Merge them into a single, comprehensive table for reasoning performance
reasoning_analysis <- merge(reasoning_accuracy, lucky_guess_rate, by = c("llm_name", "prompt_technique"))
reasoning_analysis <- merge(reasoning_analysis, fully_correct_rate, by = c("llm_name", "prompt_technique"))

print("Reasoning Analysis (for CoT and ReAct Prompts")
print(reasoning_analysis)

# Statistical Significance Testing
# Test 1: Is there a significant difference in overall accuracy among prompt techniques?
accuracy_test <- chisq.test(table(new_df$prompt_technique, new_df$correctness_flag))
print("Chi-Squared Test for Prompt Technique vs. Accuracy")
print(accuracy_test)

# Test 2: Is there a significant difference in reasoning accuracy between LLMs for the ReAct prompt?
react_df <- new_df[new_df$prompt_technique == "ReAct", ]
reasoning_accuracy_test_react <- chisq.test(table(react_df$llm_name, react_df$reasoning_correct_flag))
print("Chi-Squared Test for LLM vs. Reasoning Accuracy (ReAct Only)")
print(reasoning_accuracy_test_react)

# Visualisations
#-------------------
# Visualisation 1: Accuracy Grouped by Prompt Technique
ggplot(model_by_prompt_performance, aes(x = prompt_technique, y = accuracy, fill = llm_name)) +
  
  # Place the bars for each LLM side-by-side.
  geom_col(position = "dodge") +
  
  # Add text labels on top of each bar for clarity
  geom_text(
    aes(label = round(accuracy, 2)), 
    position = position_dodge(width = 0.9), 
    vjust = -0.5, # Adjust to place text just above the bar
    size = 3.5
  ) +
  
  # Manually set the four colors for the prompt techniques to be colour-blind friendly
  scale_fill_brewer(palette = "Set1") +
  
  # Set the y-axis limits
  ylim(0, 1) +
  
  # Add all titles and labels
  labs(
    title = "Overall Accuracy for Model and Prompt Interaction",
    x = "Prompt Technique",
    y = "Accuracy",
    fill = "LLM Name" # Sets the legend title
  ) +
  
  facet_wrap(~ llm_name)+

  # Apply a clean theme
  theme(
    # Rotate x-axis labels to prevent overlap
    axis.text.x = element_text(angle = 50, hjust = 0.9, vjust = 1),
    # Center the plot title
    plot.title = element_text(hjust = 0.5),
    # Increase base font size for readability
    text = element_text(size = 10)
  )


# Visualisation 2: Accuracy Grouped by LLM Name
ggplot(model_by_prompt_performance, aes(x = llm_name, y = accuracy, fill = prompt_technique)) +
  
  # geom_col with position="dodge" again creates the grouped bars
  geom_col(position = "dodge") +
  
  # Add text labels on top of each bar
  geom_text(
    aes(label = round(accuracy, 2)), 
    position = position_dodge(width = 0.9), 
    vjust = -0.5,
    size = 3.5
  ) +
  
  # Manually set the four colors for the prompt techniques to be colour-blind friendly
  scale_fill_brewer(palette = "Set1") +
  
  # Set the y-axis limits
  ylim(0, 1) +
  
  # Add all titles and labels
  labs(
    title = "Overall Model Accuracy by LLM Name",
    x = "LLM Name",
    y = "Accuracy",
    fill = "Prompt Technique"
  ) +
  
  # Apply a clean theme
  facet_wrap(~ prompt_technique)+
  
  # Apply a clean theme
  theme_minimal()+
  theme(
    # Rotate x-axis labels to prevent overlap
    axis.text.x = element_text(angle = 50, hjust = 0.9, vjust = 1),
    # Center the plot title
    plot.title = element_text(hjust = 0.5),
    # Increase base font size for readability
    text = element_text(size = 10)
  )
# Visualisation 3: Stacked Bar Chart for Composition of Correct Answers
reasoning_analysis$prop_fully_correct <- reasoning_analysis$fully_correct_flag / (reasoning_analysis$fully_correct_flag + reasoning_analysis$correct_answer_incorrect_reasoning_flag)
reasoning_analysis$prop_lucky_guess <- reasoning_analysis$correct_answer_incorrect_reasoning_flag / (reasoning_analysis$fully_correct_flag + reasoning_analysis$correct_answer_incorrect_reasoning_flag)

# Select only the proportion columns needed for the plot.
plot_data_subset <- reasoning_analysis[, c("prop_lucky_guess", "prop_fully_correct")]

# Convert the data frame subset to a matrix and transpose it.
# The barplot() function expects each column to be a bar, and the rows to be the stacked values.
plot_data_matrix <- t(as.matrix(plot_data_subset))

# Assign column names for the x-axis labels.
colnames(plot_data_matrix) <- paste(reasoning_analysis$llm_name, reasoning_analysis$prompt_technique)

# Assign row names, which will be used for the legend.
# We reverse the order so "Fully Correct" is at the bottom of the stack.
rownames(plot_data_matrix) <- c("Lucky Guess", "Fully Correct")

# Create the final barplot with the correctly formatted matrix.
df_correct <- reasoning_analysis[, c("llm_name", "prompt_technique", "prop_fully_correct")]
df_correct$outcome_type <- "Fully Correct"
# Rename the proportion column to a generic name for merging
names(df_correct)[3] <- "proportion"

# Create a data frame for the "Lucky Guess" proportions
df_lucky <- reasoning_analysis[, c("llm_name", "prompt_technique", "prop_lucky_guess")]
df_lucky$outcome_type <- "Lucky Guess"
# Rename the proportion column to the same generic name
names(df_lucky)[3] <- "proportion"

# Combine the two data frames into a single "long" data frame
reasoning_long <- rbind(df_correct, df_lucky)

# Inspect the final 'long' data frame
print(head(reasoning_long))

# Create the plot using the prepared data
ggplot(reasoning_long, aes(x = paste(llm_name, prompt_technique), y = proportion, fill = outcome_type)) +
  # Create the stacked bars. geom_col() is used for pre-calculated y-values.
  geom_col() +
  
  # Manually set the four colors for the prompt techniques to be colour-blind friendly
  scale_fill_brewer(palette = "Set1") +
  
  # Add all titles and labels
  labs(
    title = "Composition of Correct Answers for Reasoning Prompts",
    x = "Model and Prompt Technique",
    y = "Proportion of Correct Answers",
    fill = "Outcome Type"
  ) +
  
  # Apply a clean theme and adjust text elements
  theme(
    # Rotate x-axis labels to prevent overlap
    axis.text.x = element_text(angle = 50, hjust = 0.9, vjust = 1),
    # Center the plot title
    plot.title = element_text(hjust = 0.5),
    # Increase base font size for readability
    text = element_text(size = 10)
  )

# Visualisation 4: Reasoning Accuracy by Prompt Technique (CoT vs ReAct only)
ggplot(reasoning_df, aes(x = prompt_technique, y = reasoning_correct_flag, fill = prompt_technique)) +
  geom_bar(stat = "summary", fun = "mean", position = position_dodge()) +
  scale_fill_brewer(palette = "Set1") +
  facet_wrap(~ llm_name) +
  labs(
    title = "Reasoning Accuracy by Prompt Technique (CoT vs ReAct)",
    x     = "Prompt Technique",
    y     = "Mean Reasoning Accuracy"
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
    plot.title  = element_text(hjust = 0.5)
  )

# Visualisation 5: Performance by Ground Truth (Yes vs No)
# Ensure ground_truth has correct ordering
ground_truth_performance$ground_truth <- factor(
  ground_truth_performance$ground_truth,
  levels = c("Yes", "No") 
)

ggplot(ground_truth_performance, 
       aes(x = prompt_technique, y = accuracy, fill = ground_truth)) +
  geom_col(position = position_dodge()) +
  facet_wrap(~ llm_name) +
  scale_fill_brewer(palette = "Set1") +
  labs(
    title = "Accuracy by Prompt Technique and Ground Truth",
    x = "Prompt Technique",
    y = "Accuracy",
    fill = "Ground Truth"
  ) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

# Visualisation 6: Performance by Question Type
ggplot(question_type_performance, 
       aes(x = question_type, y = accuracy, fill = prompt_technique)) +
  geom_col(position = position_dodge()) +
  facet_wrap(~ llm_name) +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Accuracy by Question Type",
       x = "Question Type",
       y = "Accuracy",
       fill = "Prompt Technique") +
  theme(plot.title = element_text(hjust = 0.5))

# Visualisation 7: Reasoning Performance by Ground Truth (ReAct only)
# Ensure ground_truth is an ordered factor
reasoning_by_truth$ground_truth <- factor(
  reasoning_by_truth$ground_truth,
  levels = c("Yes", "No")
)

ggplot(reasoning_by_truth, 
       aes(x = ground_truth, y = reasoning_accuracy, fill = llm_name)) +
  geom_col(position = position_dodge()) +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Reasoning Accuracy by Ground Truth",
       x = "Ground Truth (Yes / No)",
       y = "Reasoning Accuracy",
       fill = "LLM") +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title = element_text(hjust = 0.5)  # centers the title
  )



# Visualisation 8: Reasoning Performance by Question Type (ReAct only)
ggplot(reasoning_by_q_type, 
       aes(x = question_type, y = reasoning_accuracy, fill = llm_name)) +
  geom_col(position = position_dodge()) +
  # Manually set the four colors for the prompt techniques to be colour-blind friendly
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Reasoning Accuracy by Question Type",
       x = "Question Type",
       y = "Reasoning Accuracy",
       fill = "LLM")

