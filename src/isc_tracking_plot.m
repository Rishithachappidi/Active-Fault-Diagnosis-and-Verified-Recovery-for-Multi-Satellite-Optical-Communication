function isc_tracking_plot(r,c,path)
f=figure('Visible','off','Color','w','Position',[100 100 1250 950]);
t=tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
nexttile;plot(r.t,r.tracking.commandError*180/pi);ylabel('Command tracking error (deg)');legend('SC1','SC2','SC3','SC4');
nexttile;plot(r.t,r.tracking.pairError*180/pi);ylabel('De-offset pair disagreement (deg)');
nexttile;plot(r.t,r.power(:,1:2)*1e6);hold on;yline(c.sensitivity*1e6,'--','HandleVisibility','off');ylabel('Affected endpoint power (microW)');
nexttile;ages=r.tracking.parentAge;ages(ages>=100)=NaN;
plot(r.t,ages);upper=max(ages,[],'all','omitnan');
if isempty(upper)||~isfinite(upper),upper=1;end
ylim([0 max(1,min(12,upper)+.25)]);ylabel('Initialized parent age (s)');legend('SC2','SC3','SC4');
nexttile;stairs(r.t,r.manager(:,2));hold on;plot(r.t,r.predictionHorizon(:,2));ylabel('SC2 local diagnosis state / horizon');legend('manager state','prediction horizon (s)');
nexttile;plot(r.t,cumsum(sum(r.attempts,2)),r.t,cumsum(sum(r.deliveries,2)));ylabel('Directed state packets');legend('attempted','delivered');
for ax=findall(f,'Type','axes')'
    grid(ax,'on');xlim(ax,[0 c.T]);xlabel(ax,'Time (s)');xline(ax,c.faultStart,':','HandleVisibility','off');xline(ax,c.faultEnd,':','HandleVisibility','off');
end
title(t,strrep(sprintf('%s | %s | manager %s | seed %d',c.mode,c.scenario,c.policy,c.seed),'_',' '));
exportgraphics(f,path,'Resolution',140);close(f);
end
