library(mvpart)

data.tr = read.table("mid_data/tag_features_for_svm_20130927.txt", header=T)
tr.num = 1:10000

m.rp = rpart(label~., data=data.tr[tr.num,])
plot(m.rp, uniform=T, branch=0.6, margin=0.05)
text(m.rp, use.n=T, all=T)

printcp(m.rp)

data.te = read.table("mid_data/tag_features_for_svm_20130927_2010000.txt", header=T)
y.te = data.te[,1]
x.te = data.te[,-1]

#y.te = data.tr[-tr.num,1]
#x.te = data.tr[-tr.num,-1]

p.te = predict(m.rp, x.te)
precision = length(p.te[p.te>0&y.te==1]) / length(p.te[p.te>0])
recall    = length(p.te[p.te>0&y.te==1]) / length(p.te[y.te==1])
