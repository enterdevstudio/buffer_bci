%% initialise the matlab paths
try; cd(fileparts(mfilename('fullpath')));catch; end;
try;
   run ../../matlab/utilities/initPaths.m
catch
   msgbox({'Please change to the directory where this file is saved before running the rest of this code'},'Change directory'); 
end

%% load the data this contains
% X - [ channels x time x epochs ] raw EEG data
% Y - [ epochs x 1 ] class labels for X's epochs
% fs- [int] sample rate of X
% Cnames - {str nCh x 1} cell array of strings for the names of X's channels
% Cpos - [2 x nCh] x-y positions of each of X's channels (for plotting)
load('ERSPdata'); 
times=(1:size(X,2))/fs; yvals=times;

%% plot the first 3 epochs of the data in a topo-graphic multi-plot
figure(1);clf;image3d(X(:,:,1:3),1,'plotPos',Cpos,'Xvals',Cnames,'Yvals',yvals,'ylabel','time (s)','disptype','plot','ticklabs','sw');
%% plot the class averages
erp = cat(3,mean(X(:,:,Y>0),3),mean(X(:,:,Y<=0),3));
figure(2);clf;image3d(erp,1,'plotPos',Cpos,'Xvals',Cnames,'Yvals',yvals,'ylabel','time (s)','Zvals',{'pos','neg'},'disptype','plot','ticklabs','sw');

zoomplots; % allow interactive zooming of the plots to see better what's going on

%% 1) detrend and try again
fprintf('1) Detrend\n');
X=detrend(X,2);

%% 2) remove bad channels
fprintf('2) bad channel removal, ');
% compute and plot the power in each channel..
chpow = sqrt(sum(X(:,:).^2,2)./size(X,2)./size(X,3)); % mean amplitude per channel
figure(1); clf;plot(chpow);
set(gca,'xtick',1:2:numel(Cnames),'xticklabel',Cnames(1:2:end)); % put on the channel names..

%% automatically identify the bad channels
[badch,feat,threshs] = idOutliers(X,1,2.5);
% show the bad channels on the power plot
figure(1);hold on;plot(find(badch),ones(size(find(badch)))*threshs(end),'r*','markersize',10); 

% remove them from the data
X=X(~badch,:,:);
% don't forget to update the channel info too!
Cpos=Cpos(:,~badch);
Cnames=Cnames(~badch);

%% 3) re-reference - CAR
fprintf('3) CAR\n');
% plot the common average signal, for all trials
figure(1);clf; plot(shiftdim(mean(X,1)))
X =X - repmat(mean(X,1),[size(X,1),1,1]);
% alt faster version: X = repop(X,'-',mean(X,1));

%% 3.5) remove bad epochs
fprintf('3.5) bad trial removal');
% plot the epoch/trial powers
eppow = sum(reshape(X,[],size(X,3)).^2,1);
figure(1); clf; plot(eppow);
% automatically identify the bad epochs
badep = idOutliers(X,3,3);
% show them one the power plot
figure(1);hold on;plot(find(badep),zeros(size(find(badep))),'*','markersize',10); 

%% store the bad examples and plot them
Xbad = X(:,:,badep); % store bad example to plot it..
% plot the bad epochs
figure(1); clf;image3d(Xbad,1,'plotPos',Cpos,'Xvals',Cnames,'Zvals',find(badep),'disptype','plot','ticklabs','sw','ylabel','samples','zlabel','epoch','clabel','uV');

% remove the bad epochs from the data
X=X(:,:,~badep);
Y=Y(~badep); % don't forget to update labels!

%%4) welch to convert to power spectral density
fprintf('4) Welch\n');
[X,wopts,winFn]=welchpsd(X,2,'width_ms',500,'fs',fs);
freqs=0:(1000/500):fs; % position of the frequency bins
yvals=freqs;

%%5) sub-select the range of frequencies we care about
freqband = [8 28];
fidx=[];
fprintf('5) Select frequencies\n');
[ans,fidx(1)]=min(abs(freqs-freqband(1))); % lower frequency bin
[ans,fidx(2)]=min(abs(freqs-freqband(2))); % upper frequency bin
X=X(:,fidx(1):fidx(2),:); % sub-set to the interesting frequency range
yvals=yvals(fidx(1):fidx(2)); % update so plots use correct info

%%6) train classifier
fprintf('6) train classifier\n');
[clsfr, res]=cvtrainLinearClassifier(X,Y,[],10);
% show the classifier structure
clsfr
%% Plot the trained classifier weight vector (only for linear classifiers)
figure(1);clf;image3d(clsfr.W,1,'plotPos',Cpos,'Xvals',Cnames,'Yvals',yvals,'disptype','plot','ticklabs','sw','ylabel','freq (hz)','zlabel','clsfr','clabel','weight'); % plot bad info

%---------------------------------------------------------------------------------------------------
%%7) use train_ersp_clsfr which does all this for you!
[clsfr,res]=train_ersp_clsfr(X,Y,'freqband',[8 28],'ch_pos',Cnames,'fs',fs);