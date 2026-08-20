# Bayes Theory
Bayes theorem is a fundamental concept in probability theory that describes the relationship between conditional probabilities. It provides a way to update our beliefs about an event based on new evidence. 

## Naive Bayes Classification
Naive Bayes is a probabilistic machine learning algorithm based on Bayes' theorem, which assumes that the features are conditionally independent given the class label. It is widely used for classification tasks, especially in text classification problems such as spam detection and sentiment analysis.

### Bayes Theorem Formula
The formula for Bayes' theorem is as follows:
'''
P(A|B) = (P(B|A) * P(A)) / P(B)
'''
Where:
- P(A|B) is the posterior probability of event A given evidence B.
- P(B|A) is the likelihood of evidence B given that event A has occurred.
- P(A) is the prior probability of event A.
- P(B) is the prior probability of evidence B. 

In the context of text/spam classification, A represents the class label (e.g., spam or not spam), and B represents the features (e.g., words in the sms).

- P(A|B) is the probability that a message is spam given the words it contains.
- P(B|A) is the probability of observing the words in the message given that it is spam.
- P(A) is the overall probability of a message being spam.
- P(B) is the overall probability of observing the words in any message.