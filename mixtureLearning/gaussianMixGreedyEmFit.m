function [m, covar, w] = gaussianMixGreedyEmFit(X,kmax,kmin)
% Maximum-likelihood fit of data 'X' on a gaussian mixture model,
% made up by at most 'kmax' kernels. All variates data vectors
% (X's columns) are assumed to be observed. Greedy EM (ala Verbeek) is
% used. Model will have at least 2 kernels.
%
% New arguments:
% ---------------
% X         Data set. Each column is one datum.
% m         dxk matrix of means. Each column is one mean.
% covar     dxdxk matrix of covariances.
% w         1xk vector of weights.
% kmax      Maximum number of mixture kernels.
%
% Old arguments:
% [W,M,R,Tlogl] = em(X,T,kmax,nr_of_cand,plo,dia)
%  X     - (n x d) d-dimensional zero-mean unit-variance data
%  T     - (m x d) test data (optional, set [] if none)
%  kmax  - maximum number of components allowed
%  nr_of_cand - number of candidates per component, zero gives non-greedy EM
%  plo   - if 1 then plot ellipses for 2-d data
%  dia   - if 1 then print diagnostics
%returns
%  W - (k x 1) vector of mixing weights
%  M - (k x d) matrix of components means
%  R - (k x d^2) matrix of Cholesky submatrices of components covariances
%      in vector reshaped format. To get the covariance of component k:
%      Rk = reshape(R(k,:),d,d); S = Rk'*Rk;
%  Tlogl -  average log-likelihood of test data
%
% See also:
%       gaussianMixEmFit
%
% Modifications -- G.Sfikas 7 feb 2007
% Nikos Vlassis & Sjaak Verbeek, oct 2002
% see greedy-EM paper at http://www.science.uva.nl/~vlassis/publications
%
X = X';
T = [];
nr_of_cand = 100;
plo = 0;
dia = 1;
[n,d] = size(X); n1=ones(n,1);d1=ones(1,d);


if d > 2 plo = 0; end
if isempty(T) test = 0;
else          test = 1;Tlogl=[];
end
if plo; figure(1);set(1,'Double','on');end
THRESHOLD = 1e-5;

if nr_of_cand 
    if nargin < 3
        k = 1;
    else
        k = kmin;
    end
  if dia; fprintf('Greedy ');end
else 
  k = kmax;
  if dia; fprintf('Non-greedy ');end
end

if dia fprintf('EM initialization\n'); end
[W,M,R,P,sigma] = em_init_km(X,k,0);
sigma=sigma^2;

oldlogl = -realmax;

while 1
  % apply EM steps to the complete mixture until convergence
  if dia     fprintf('EM steps');  end
  while 1
    [W,M,R] = em_step(X,W,M,R,P,plo);
    if dia       fprintf('.');     end
    % likelihoods L (n x k) for all inputs and all components
    L = em_gauss(X,M,R);
    % mixture F (n x 1) and average log-likelihood
    F = L * W;
    F(find(F < realmin)) = realmin;
    logl = mean(log(F)); 
    
    % posteriors P (n x k) and their sums
    P = L .* (ones(n,1)*W')  ./ (F*ones(1,k));
        
    if abs(logl/oldlogl-1) < THRESHOLD
      if dia         fprintf('\n');        fprintf('Logl = %g\n', logl);end
      break;
    end
    oldlogl = logl;
  end

 if test % average log-likelihood of test set
      Ft = em_gauss(T,M,R) * W;
      Ft(find(Ft < eps)) = eps;
      Tlogl = [Tlogl; mean(log(Ft))];
 else
   Tlogl=0;
 end

  if k == kmax;
      [m covar w] = cleanUp(M, R, W);
      return;  end

  if dia    fprintf('Trying component allocation');  end
  [Mnew,Rnew,alpha] = rand_split(P,X,M,R,sigma,F,W,nr_of_cand); 
  if alpha==0
    if test % average log-likelihood of test set
      Ft = em_gauss(T,M,R) * W;
      Ft(find(Ft < eps)) = eps;
      Tlogl = [Tlogl; mean(log(Ft))];
    else
      Tlogl=0; 
    end
    if k == 1 && kmax > 1
        if dia fprintf('Mixture uses only %d components\n', k);end
        [m covar w] = gaussianMixGreedyEmFit(X', kmax, 2);
        return;
    end
    [m covar w] = cleanUp(M, R, W);
    return;
  end
  K                 = em_gauss(X,Mnew,Rnew);
  PP                = F*(1-alpha)+K*alpha;
  LOGL              = mean(log(PP));

  % optimize new mixture with partial EM steps updating only Mnew,Rnew
  veryoldlogl = logl; oldlogl = LOGL;done_here=0;
  Pnew = (K.*(ones(n,1)*alpha))./PP;
  while ~done_here
    if dia         fprintf('*');    end
    [alpha,Mnew,Rnew] = em_step(X,alpha,Mnew,Rnew,Pnew,0);
    K    = em_gauss(X,Mnew,Rnew); Fnew = F*(1-alpha)+K*alpha;
    Pnew = K*alpha./Fnew;         logl = mean(log(Fnew));
    if abs(logl/oldlogl-1)<THRESHOLD done_here=1;end
    oldlogl=logl;
  end
  % check if log-likelihood increases with insertion
  if logl <= veryoldlogl
    if dia fprintf('Mixture uses only %d components\n', k);end
    if test % average log-likelihood of test set
      Ft = em_gauss(T,M,R) * W; Ft(find(Ft < eps)) = eps;
      Tlogl = [Tlogl; mean(log(Ft))];
    else Tlogl=0; end
    if k == 1 && kmax > 1
        if dia fprintf('Mixture uses only %d components\n', k);end
        [m covar w] = gaussianMixGreedyEmFit(X', kmax, 2);
        return;
    end
    [m covar w] = cleanUp(M, R, W);
    return;
  end
  % allocate new component
  M = [M; Mnew];
  R = [R; Rnew];
  W = [(1-alpha)*W; alpha];
  k = k + 1;
  if dia   fprintf(' k = %d\n', k);fprintf('LogL = %g\n', logl);end
  % prepare next EM step
  L = em_gauss(X,M,R);
  F = L * W;F(find(F<realmin))=realmin;
  P = L .* (ones(n,1)*W')  ./ (F*ones(1,k));
end
%
% Modify returned results
for i = 1:size(R, 1)
    Rk = reshape(R(i,:),d,d);
    covar(:,:,i) = Rk'*Rk;
end
m = M';
w = W';
return;

function [m covar w] = cleanUp(M, R, W);
% Modify returned results
k = size(R, 1);
d = size(M, 2);
for i = 1:k
    Rk = reshape(R(i,:),d,d);
    covar(:,:,i) = Rk'*Rk;
end
m = M';
w = W';
return;


function [W,M,R,P,sigma] = em_init_km(X,k,dyn)
%em_init_km - initialization of EM for Gaussian mixtures 
%
%[W,M,R,P,sigma] = em_init_km(X,k,dyn)
%  X - (n x d) matrix of input data 
%  k - initial number of Gaussian components
%  dyn - if 1 then perform dynamic component allocation else normal EM 
%returns
%  W - (k x 1) vector of mixing weights
%  M - (k x d) matrix of components means
%  R - (k x d^2) matrix of Cholesky submatrices of components covariances
%  P - (n x k) the posteriors to be used in EM step after initialization
%  of priors, means, and components covariance matrices

% Nikos Vlassis & Sjaak Verbeek 2002

[n,d] = size(X);

[tmp,M,tmp2] = kmeans(X,[],k,0,0,0,0);
[D,I]        = min(sqdist(M',X'),[],1);

% mixing weights
W = zeros(k,1);
for i=1:k
  W(i) = length(find(I==i))/n;  
end

% covariance matrices 
R = zeros(k,d^2);
if k > 1
  for j = 1:k
    J = find(I==j);
    if length(J)>2*d;Sj = cov(X(J,:));else Sj=cov(X);end
    Rj = chol(Sj);
    R(j,:) = Rj(:)';
  end
else
  S = cov(X);
  R = chol(S);
  R = R(:)';
end

% compute likelihoods L (n x k)
L = em_gauss(X,M,R);

% compute mixture likelihoods F (n x 1)
F = L * W;
F(find(F < eps)) = eps;

% compute posteriors P (n x k)
P = L .* repmat(W',n,1)  ./ repmat(F,1,k);

sigma = 0.5 * (4/(d+2)/n)^(1/(d+4)) * sqrt(norm(cov(X)));

return;









function L = em_gauss(X,M,R)
%em_gauss - compute likelihoods for all points and all components
%
%L = em_gauss(X,M,R)
%  X - (n x d) matrix of input data
%  M - (k x d) matrix of components means
%  R - (k x d^2) matrix of Cholesky submatrices of components covariances
%      in vector reshaped format. To get the covariance of component k:
%      Rk = reshape(R(k,:),d,d); S = Rk'*Rk;
%returns 
%  L - (n x k) likelihoods of points x_n belonging to component k

% Nikos Vlassis, 2000

[n,d] = size(X);
k = size(M,1);

L = zeros(n,k); 
for j = 1:k 

  % Cholesky triangular matrix of component's covariance matrix
  Rj = reshape(R(j,:),d,d);        
  
  % We need to compute the Mahalanobis distances between all inputs
  % and the mean of component j; using the Cholesky form of covariances
  % this becomes the Euclidean norm of some new vectors 
  New = (X - repmat(M(j,:),n,1)) * inv(Rj);
  Mah = sum(New.^2,2);

  L(:,j) = (2*pi)^(-d/2) / det(Rj) * exp(-0.5*Mah);
end









function [W,M,R] = em_step(X,W,M,R,P,plo)
%em_step - EM learning step for multivariate Gaussian mixtures
%
%[W,M,R] = em_step(X,W,M,R,P,plo)
%  X - (n x d) matrix of input data
%  W - (k x 1) vector of mixing weights
%  M - (k x d) matrix of components means
%  R - (k x d^2) matrix of Cholesky submatrices of components covariances
%      in vector reshaped format. To get the covariance of component k:
%      Rk = reshape(R(k,:),d,d); S = Rk'*Rk;
%  P - (n x k) posterior probabilities of all components (from previous EM step)
%  plo - if 1 then plot ellipses for 2-d data
%returns
%  W - (k x 1) matrix of components priors
%  M - (k x d) matrix of components means
%  R - (k x d^2) matrix of Cholesky submatrices of components covariances

% Nikos Vlassis, 2000

[n,d] = size(X);


if plo 
  figure(1);
  if d == 1
    plot(X,zeros(n,1),'k+');
  else
    plot(X(:,1),X(:,2),'g+');   
  end
  hold on; 
end

Psum = sum(P,1);  

for j = 1:length(W)
  if Psum(j) > eps
   % update mixing weight
    W(j) = Psum(j) / n;
    % update mean
    M(j,:) = P(:,j)' * X ./ Psum(j);
  
    % update covariance matrix
    Mj = repmat(M(j,:),n,1);
    Sj = ((X - Mj) .* repmat(P(:,j),1,d))' * (X - Mj) ./ repmat(Psum(j),d,d);

    % check for singularities
    [U,L,V] = svd(Sj); 
    l = diag(L);
    if (min(l) > eps) & (max(l)/min(l) < 1e4)
      [Rj,p] = chol(Sj);
      if p == 0
        R(j,:) = Rj(:)';
      end
    end

    % plot ellipses
    if plo 
     if d == 1
       x = linspace(min(X)-3*max(R),max(X)+3*max(R),500)';
       Lx = em_gauss(x,M,R);
       Fx = Lx*W;
       plot(x,Fx,'k-');
     else
      Rk = reshape(R(j,:),d,d); S = Rk'*Rk;l=svd(S);
      phi = acos(V(1,1));
      if V(2,1) < 0
        phi = 2*pi - phi;
      end
      plot(M(j,1),M(j,2),'k.',M(j,1),M(j,2),'k+');
      ellipse(2*sqrt(l(1)),2*sqrt(l(2)),phi,M(j,1),M(j,2),'k'); 
    end
   end
  end
end

if plo
  if  d==2
    a = (max(X(:,1)) - min(X(:,1))) / 10;
    b = (max(X(:,2)) - min(X(:,2))) / 10;
    axis([min(X(:,1))-a max(X(:,1))+a min(X(:,2))-b max(X(:,2))+b]);
  end
  drawnow;
  hold off;
end


return;





function [W,M,R] = em_step_partial(X,W,M,R,P,n_all,plo)

[n,d] = size(X); n1=ones(n,1);d1=ones(1,d);
if plo  figure(1), plot(X(:,1),X(:,2),'g+'); hold on; end
Psum = sum(P);  

for j = 1:length(W)
  if Psum(j) > realmin
    W(j) = Psum(j) / n_all;
    M(j,:) = P(:,j)' * X ./ Psum(j);
    Mj = X-n1*M(j,:);
    Sj = (Mj .* (P(:,j)*d1))' * Mj / Psum(j);
    % check for singularities
    L = svd(Sj);  % get smallest eigenvalue
    if L(d) > realmin 
      [Rj,p] = chol(Sj);
      if p == 0
        R(j,:) = Rj(:)';
      end
    end
    % plot ellipses
    if plo
      [U,L,V] = svd(Sj); 
      phi = acos(V(1,1));
      if V(2,1) < 0
        phi = 2*pi - phi;
      end
      plot(M(j,1),M(j,2),'k.',M(j,1),M(j,2),'k+');
      ellipse(2*sqrt(l(1)),2*sqrt(l(2)),phi,M(j,1),M(j,2),'k'); 
    end

  end
end

if plo
  a = (max(X(:,1)) - min(X(:,1))) / 10;
  b = (max(X(:,2)) - min(X(:,2))) / 10;
  drawnow;
  hold off;
end
return;




function [Mus, Covs, Ws]=rand_split(P,X,M,R,sigma,F,W,nr_of_cand)

k       = size(R,1);
[n,d]   = size(X);
epsilon = 1e-2;      % threshold in relative loglikelihood improvement for convergence in local partial EM 

[tmp,I] = max(P,[],2);

Mus=[];Covs=[];K=[];Ws=[];KL=[];



for i=1:k
    
  XI        = find(I==i);
  Xloc      = X(XI,:);   
  start     = size(Mus,1);    
  j=0;

  if length(XI) > 2*d  % generate candidates for this parent
     while j < nr_of_cand  % number of candidates per parent component
       r  = randperm(length(XI));    r  = r(1:2);
      if d==1
        cl = [Xloc-Xloc(r(1)) Xloc-Xloc(r(2))]; 
        [tmp,cl] = min(cl.^2,[],2);
      else      
        cl = sqdist( Xloc', Xloc(r,:)' ); 
        [tmp,cl] = min(cl,[],2);
      end
      for guy = 1:2
        data = Xloc( find( cl==guy ), :); 
        if size(data,1) > d
          j = j + 1;
          Mus  = [Mus; mean(data)];
          Rloc = cov(data) + eye(d)*eps;
          Rloc = chol(Rloc);
          Covs = [Covs; Rloc(:)'];
          Ws   = [Ws W(i)/2];
          Knew = zeros(n,1);
          Knew(XI) = em_gauss(Xloc,Mus(end,:),Covs(end,:));
          K = [K Knew];
        end
      end
    end
  end


  last=size(Mus,1); if last>start % if candidates were added, do local partial EM
    alpha= Ws(start+1:last); K2=K(XI,start+1:last);Mnew=Mus(start+1:last,:);
    Rnew=Covs(start+1:last,:);
    FF   = F(XI)*ones(1,last-start);
    PP   = FF.*(ones(length(XI),1)*(1-alpha))+K2.*(ones(length(XI),1)*alpha);
    Pnew = (K2.*(ones(length(XI),1)*alpha))./PP;
    OI   = ones(n,1);OI(XI)=0;OI=find(OI==1);
    lpo   = sum(log(F(OI)));
    ll = sum(log(PP)) + length(OI)*log(1-alpha)+lpo;ll=ll/n;done=0;
    iter=1;
    while ~done
      [alpha,Mnew,Rnew] = em_step_partial(Xloc,alpha,Mnew,Rnew,Pnew,n,0); 
      K2 = em_gauss(Xloc,Mnew,Rnew); 
      Fnew = FF.*(ones(length(XI),1)*(1-alpha))+K2.*(ones(length(XI),1)*alpha);
      old_ll = ll; ll=sum(log(Fnew))+length(OI)*log(1-alpha)+lpo; ll=ll/n;
      done = abs(max(ll/old_ll -1))<epsilon;
      if iter>20; done=1;end;iter=iter+1;
      Pnew = (K2.*(ones(length(XI),1)*alpha))./Fnew;
    end   
    Pnew(find(Pnew<eps))=eps;
    Pnew(find(Pnew==1))=1-eps;
    Ws(start+1:last)=alpha;
    Mus(start+1:last,:)=Mnew; 
    Covs(start+1:last,:)=Rnew;
    KL = [KL n*log(1-alpha)-sum(log(1-Pnew))];
  end
end

I=[];for i=1:length(Ws) % remove some candiates that are unwanted
  S=reshape(Covs(i,:),d,d);S=S'*S;S=min(eig(S));
  if (S<sigma/400 | Ws(i)<2*d/n  | Ws(i)>.99) I=[I i];end
end
Ws(I)=[];KL(I)=[];Mus(I,:)=[];Covs(I,:)=[];


if isempty(Ws)
  Ws=0;
else
  [logl sup]=max(KL);sup=sup(1);
  Mus=Mus(sup,:); Covs=Covs(sup,:);Ws=Ws(sup);
end
return;








function d = sqdist(a,b)
% sqdist - computes pairwise squared Euclidean distances between points

% original version by Roland Bunschoten, 1999

if size(a,1)==1
  d = repmat(a',1,length(b)) - repmat(b,length(a),1); 
  d = d.^2;
else
  aa = sum(a.*a); bb = sum(b.*b); ab = a'*b; 
  d = abs(repmat(aa',[1 size(bb,2)]) + repmat(bb,[size(aa,2) 1]) - 2*ab);
end
return;







function [Er,M,nb] = kmeans(X,T,kmax,dyn,bs, killing, pl)
% kmeans - clustering with k-means (or Generalized Lloyd or LBG) algorithm
%
% [Er,M,nb] = kmeans(X,T,kmax,dyn,dnb,killing,p)
%
% X    - (n x d) d-dimensional input data
% T    - (? x d) d-dimensional test data
% kmax - (maximal) number of means
% dyn  - 0: standard k-means, unif. random subset of data init. 
%        1: fast global k-means
%        2: non-greedy, just use kdtree to initiallize the means
%        3: fast global k-means, use kdtree for potential insertion locations  
%        4: global k-means algorithm
% dnb  - desired number of buckets on the kd-tree  
% pl   - plot the fitting process
%
% returns
% Er - sum of squared distances to nearest mean (second column for test data)
% M  - (k x d) matrix of cluster centers; k is computed dynamically
% nb - number of nodes on the kd-tree (option dyn=[2,3])
%
% Nikos Vlassis & Sjaak Verbeek, 2001, http://www.science.uva.nl/~jverbeek

Er=[]; TEr=[];              % error monitorring

[n,d]     = size(X);

THRESHOLD = 1e-4;   % relative change in error that is regarded as convergence
nb        = 0;  

% initialize 
if dyn==1            % greedy insertion, possible at all points
  k      = 1;
  M      = mean(X);
  K      = sqdist(X',X');
  L      = X;
elseif dyn==2        % use kd-tree results as means
  k      = kmax;
  M      = kdtree(X,[1:n]',[],1.5*n/k); 
  nb     = size(M,1);
  dyn    = 0;
elseif dyn==3
  L      = kdtree(X,[1:n]',[],1.5*n/bs);  
  nb     = size(L,1);
  k      = 1;
  M      = mean(X);
  K      = sqdist(X',L');
elseif dyn==4
  k      = 1;
  M      = mean(X);
  K      = sqdist(X',X');
  L      = X;
else                 % use random subset of data as means
  k      = kmax;
  tmp    = randperm(n);
  M      = X(tmp(1:k),:); 
end

Wold = realmax;

while k <= kmax
  kill = [];

  % squared Euclidean distances to means; Dist (k x n)
  Dist = sqdist(M',X');  

  % Voronoi partitioning
  [Dwin,Iwin] = min(Dist',[],2);

  % error measures and mean updates
  Wnew = sum(Dwin);
 
  % update VQ's
  for i=1:size(M,1)
    I = find(Iwin==i);
    if size(I,1)>d
      M(i,:) = mean(X(I,:));
  elseif killing==1
      kill = [kill; i];
    end
  end

 if 1-Wnew/Wold < THRESHOLD*(10-9*(k==kmax))
    if dyn & k < kmax
   
      if dyn == 4
        best_Er = Wnew; 

        for i=1:n;
    	  Wold = Inf;
       	  Wtmp = Wnew;
          Mtmp = [M; X(i,:)];
          while (1-Wtmp/Wold) > THRESHOLD*10; 
	    Wold = Wtmp;
            Dist = sqdist(Mtmp',X');  
            [Dwin,Iwin] = min(Dist',[],2);
            Wtmp = sum(Dwin);
            for i = 1 : size(Mtmp,1)
              I = find(Iwin==i);
              if size(I,1)>d; Mtmp(i,:) = mean(X(I,:)); end
            end
          end
          if Wtmp < best_Er;   best_M = Mtmp; best_Er = Wtmp; end
        end

        M = best_M;
        Wnew = best_Er;
        if ~isempty(T); tmp=sqdist(T',M'); TEr=[TEr; sum(min(tmp,[],2))];end;
        Er=[Er; Wnew];
        k = k+1;

      else 
        % try to add a new cluster on some point x_i
        [tmp,new] = max(sum(max(repmat(Dwin,1,size(K,2))-K,0)));
        k = k+1;
        M = [M; L(new,:)+eps];
        if pl;        fprintf( 'new cluster, k=%d\n', k);      end
        [Dwin,Iwin] = min(Dist',[],2);
	Wnew        = sum(Dwin);Er=[Er; Wnew];
        if ~isempty(T); tmp=sqdist(T',M'); TEr=[TEr; sum(min(tmp,[],2))];end;
      end
    else
      k = kmax+1;
    end  
  end
  Wold = Wnew;
  if pl
    figure(1); plot(X(:,1),X(:,2),'g.',M(:,1),M(:,2),'k.',M(:,1),M(:,2),'k+');
    drawnow;
  end
end

 Er=[Er; Wnew];
 if ~isempty(T); tmp=sqdist(T',M'); TEr=[TEr; sum(min(tmp,[],2))]; Er=[Er TEr];end;
M(kill,:)=[];

return;