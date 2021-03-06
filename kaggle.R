# STATS 202 Kaggle Competition

# Clear workspace
rm(list=ls())

# Import Data
houses <- read.csv("train.csv", header = TRUE)
test <- read.csv("test.csv", header = TRUE)

# Exploratory examination of the data
pairs(houses)
cor(houses)

set.seed(123)

# Simple multiple linear regression'
houses.dat <- houses[-1, ]
mlm.fit <- lm(Value ~., data = houses.dat)
par(mfrow=c(2,2))
plot(mlm.fit) # Not sure what to make of the residuals distribution, thoughts?

# We have some awful outliers with super high leverage (point 5 I think) and another with high leverage and high
# residuals (point 78), so maybe we should remove those?
# Other points to consider: 6 and 81
# Outlier Removal
houses2 <- houses[-c(5, 78), ] # taknin' out them bad hombres 

# Double check the leverage and residuals after omitting outliers
houses.dat <- houses2[-1, ]
mlm.fit2 <- lm(Value ~., data = houses.dat)
plot(mlm.fit2)

par(mfrow=c(1,1))

idx <- sample(nrow(houses2), 60)
training <- houses2[idx, ]
testing <- houses2[-idx, ]

# ---> @Dan, 
#   I don't think the relationships look linear in any sense, so I am going to punt on trying Ridge/Lasso
#   I set up some cross validation stuff, but I don't think it is working out.   

# Cross validation for best subset selection
# library(leaps)
# regfit.best <- regsubsets(Value ~., data = training[, -1], nvmax = 7)
# test.mat <- model.matrix(Value ~., data = testing[, -1])
# val.errors <- rep(NA, 7)
# for(i in 1:7){
#   this.coef <- coef(regfit.best, id = i)
#   preds <- test.mat[, names(this.coef)] %*% this.coef
#   val.errors[i] = mean((testing$Value - preds)^2)
# }

# PLS might be a good idea because it will let us fit more smoothly while still maintaining that simplistic linear
# relationship.
# For the above, I meant local linear regression. My bad. Will re-do later if decision tree doesn't work out.

# # Partial least squares regression
# library(pls)
# pls.fit <- plsr(Value ~., data = training, scale = TRUE, validation = "CV")
# summary(pls.fit)
# validationplot(pls.fit, val.type = "MSEP")
# pls.pred <- predict(pls.fit, testing, ncomp = 3) # using 3 PC's b/c no longer increases by > 1% for more
# pls.mse <- mean((pls.pred - testing$Value)^2)

# @Dan,
# I think I am going to implement a decision tree to carve up the data into more manageable sections based on
# some of the factor variables such as stories, fireplaces, zip code, and bathrooms. Then I think we should 
# do partial least squares or local linear regression within each section. Then we can stitch them all together to
# form our final model. Thoughts?

# Decision Tree
# Factors: YearBuilt, Story, Baths, Fireplaces, Zip
library(tree)
set.seed(123)
tree.training <- training[, -1]

tree.training$Value <- log(tree.training$Value) # log transform the values to produce a more normal distribution
tree.training$Story <- as.factor(tree.training$Story)
tree.training$Baths <- as.factor(tree.training$Baths)
tree.training$Fireplaces <- as.factor(tree.training$Fireplaces)
tree.training$Zip <- as.factor(tree.training$Zip)
tree.training <- na.omit(tree.training)

tree.testing <- testing[, -1]
tree.testing$Value <- log(tree.testing$Value) # log transform the values to produce a more normal distribution
tree.testing$Story <- as.factor(tree.testing$Story)
tree.testing$Baths <- as.factor(tree.testing$Baths)
tree.testing$Fireplaces <- as.factor(tree.testing$Fireplaces)
tree.testing$Zip <- as.factor(tree.testing$Zip)
tree.testing <- na.omit(tree.testing)

# preliminary tree fit to get an idea of effectiveness
houses.tree <- tree(Value ~ ., data = tree.training[, ])
tree.s <- summary(tree.fit)
tree.s
plot(houses.tree)
text(houses.tree, pretty = 1)
mtext("Preliminary Regression Tree", side = 3, padj = -2, font = 2)
mtext(paste("MSE: ", mean(tree.s$residuals^2)), side = 1, padj = 1)

# calculate test MSE
tree.preds <- predict(houses.tree, newdata = tree.testing) # estimated test values
tree.testmse <- exp(mean((tree.preds - tree.testing$Value)^2)) # scaled to the original data 

# maximizing tree efficacy with cross validation and pruning
houses.treeCV <- cv.tree(houses.tree)
plot(houses.treeCV$size, houses.treeCV$dev/houses.treeCV$size ,type = 'b', main = "CV Plot of Regression Tree", 
     xlab = "Size of Tree", ylab = "Mean Deviances by Size")
points(which.min(rev(houses.treeCV$dev)), min(houses.treeCV$dev/houses.treeCV$size), col = "red", pch = 19)

# prune tree maybe?
# houses.pruned =prune.tree(houses.tree, best = 7)
# plot(houses.prune)
# text(houses.prune, pretty = 0)

# Boost the tree
library(gbm)
set.seed(123)
lambdas <- seq(from = 0.0001, to = 0.001, length.out = 10)
errs <- rep(NA, 10)
for(i in 1:length(lambdas)){
  houses.boost <- gbm(Value ~., data = tree.training, distribution= "gaussian", n.trees = 5000, shrinkage = lambdas[i])
  boost.s <- summary(houses.boost)
  #plot(houses.boost, main = "Boosting Results")
  preds.boost <- predict (houses.boost, newdata = tree.testing, n.trees =5000)
  boost.testmse <- exp(mean((preds.boost - tree.testing$Value)^2))
  errs[i] <- boost.testmse
}
plot(lambdas, errs, main = "Test MSE by Shrinkage", type = 'b', xlab = "Shrinkage (Lambda)", ylab = "Test MSE")
points(lambdas[which.min(errs)], min(errs), col = "red", pch = 19)

houses.boost <- gmb(Value ~., data = tree.training, distribution = "gaussian", n.trees = 5000, shrinkage = lambda[which.min(errs)])

### --- PRELIMINARY TEST --- ###

testnow <- test[, -1]
testnow$Story <- as.factor(testnow$Story)
testnow$Baths <- as.factor(testnow$Baths)
testnow$Fireplaces <- as.factor(testnow$Fireplaces)
testnow$Zip <- as.factor(testnow$Zip)
testnow <- na.omit(testnow)

preds <- predict(houses.boost, newdata = testnow, n.trees = 5000) # estimated test values
preds <- exp(preds)
estimates <- cbind(1:10, preds)
colnames(estimates) <- c("ID", "Predicted")
write.csv(estimates, "test-predictions.csv", row.names = FALSE)
View(cbind(estimates[, 1], testnow, estimates[, 2]))


