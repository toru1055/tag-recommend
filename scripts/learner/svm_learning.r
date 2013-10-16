library(LiblineaR);
svmdata = read.table("mid_data/tag_features_for_svm_20130927.txt", header=T)
testdata = read.table("mid_data/tag_features_for_svm_20130927_2010000.txt", header=T)
#tr.num = 1:(length(svmdata[,1]) / 2)
tr.num = 1:10000

y.tr = svmdata[tr.num,1]
x.tr2 = svmdata[tr.num,-1]
x.tr = cbind(x.tr2,x.tr2)
x.tr[x.tr2[,1]>0.1,1] = 0.0
x.tr[x.tr2[,1]>0.1,2] = 0.0
x.tr[x.tr2[,1]>0.1,3] = 0.0
x.tr[x.tr2[,1]>0.1,4] = 0.0
x.tr[x.tr2[,1]<0.1,7] = 0.0
x.tr[x.tr2[,1]<0.1,8] = 0.0
x.tr[x.tr2[,1]<0.1,9] = 0.0
x.tr[x.tr2[,1]<0.1,10] = 0.0

#y.te = svmdata[-tr.num,1]
#x.te = svmdata[-tr.num,-1]
y.te = testdata[,1]
x.te2 = testdata[,-1]
x.te = cbind(x.te2,x.te2)
x.te[x.te2[,1]>0.1,1] = 0.0
x.te[x.te2[,1]>0.1,2] = 0.0
x.te[x.te2[,1]>0.1,3] = 0.0
x.te[x.te2[,1]>0.1,4] = 0.0
x.te[x.te2[,1]<0.1,7] = 0.0
x.te[x.te2[,1]<0.1,8] = 0.0
x.te[x.te2[,1]<0.1,9] = 0.0
x.te[x.te2[,1]<0.1,10] = 0.0

s=scale(x.tr,center=TRUE,scale=TRUE)
co=heuristicC(s)
m=LiblineaR(data=s,labels=y.tr,type=1,cost=co,bias=TRUE,verbose=FALSE)

s2=scale(x.te,attr(s,"scaled:center"),attr(s,"scaled:scale"))
p=predict(m,s2,proba=FALSE,decisionValues=TRUE)

#plot(p$decisionValues[,1], y.te)
plot(density(p$decisionValues[y.te==-1,1]), xlim=c(-2,8), ylim=c(0,1), col="red");
par(new=T);
plot(density(p$decisionValues[y.te==1,1]),  xlim=c(-2,8), ylim=c(0,1));

# eval
true_false = (p$predictions * y.te)
accuracy = length(true_false[true_false==1]) / length(true_false)

p_score = p$decisionValues[,1]

pos = y.te[p_score>0]
precision0 = length(pos[pos==1]) / length(pos)

pos = y.te[p_score>1]
precision1 = length(pos[pos==1]) / length(pos)

pos = y.te[p_score>2]
precision2 = length(pos[pos==1]) / length(pos)

pos = y.te[p_score>3]
precision3 = length(pos[pos==1]) / length(pos)

write.table(attr(s,"scaled:center"), file="mid_data/feature_center.txt", sep="\t", row.names = TRUE, col.names = F, quote=F)
write.table(attr(s,"scaled:scale"), file="mid_data/feature_scale.txt", sep="\t", row.names = TRUE, col.names = F, quote=F)
write.table(t(-m$W), file="mid_data/feature_weights.txt", sep="\t", row.names = TRUE, col.names = F, quote=F)
