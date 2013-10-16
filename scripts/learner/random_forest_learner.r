library(randomForest);
data.tr = read.table("mid_data/tag_features_for_svm_20130927.txt", header=T)
tr.num = 1:10000

m.rf = randomForest(as.factor(label)~., data=data.tr[tr.num,])
print(m.rf)
varImpPlot(m.rf)

data.te = read.table("mid_data/tag_features_for_svm_20130927_2010000.txt", header=T)
y.te = data.te[,1]
x.te = data.te[,-1]

#y.te = data.tr[-tr.num,1]
#x.te = data.tr[-tr.num,-1]

p.te = predict(m.rf, x.te)
rft = table(y.te, p.te)
print(rft)

p.te = as.numeric(p.te)-1
pos = y.te[p.te>0]
precision0 = length(pos[pos==1]) / length(pos)

precision = length(p.te[p.te>0&y.te==1]) / length(p.te[p.te>0])
recall    = length(p.te[p.te>0&y.te==1]) / length(p.te[y.te==1])

