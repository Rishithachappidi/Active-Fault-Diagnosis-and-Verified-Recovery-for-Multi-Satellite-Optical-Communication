function isc_plot(r,c,path)
f=figure('Visible','off','Color','w','Position',[80 80 1200 900]);
tl=tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
angle=squeeze(sqrt(sum(r.att.^2,2)));
nexttile;plot(r.t,angle*180/pi,'LineWidth',1);ylabel('Attitude error (deg)');legend('SC1','SC2','SC3','SC4');grid on;
nexttile;plot(r.t,r.power(:,1:2)*1e6);hold on;yline(c.sensitivity*1e6,'--');ylabel('SC1-SC2 power (microW)');grid on;
nexttile;stairs(r.t,r.up(:,1),'LineWidth',1);ylim([-0.1 1.1]);ylabel('SC1-SC2 session available');grid on;
nexttile;plot(r.t,squeeze(r.correction(:,:,1))*1e6);ylabel('Terminal 1 correction (microrad)');grid on;
nexttile;plot(r.t,cumsum(sum(r.attempts,2)),r.t,cumsum(sum(r.deliveries,2)));legend('Attempts','Deliveries','Location','northwest');ylabel('Directed packets');grid on;
nexttile;plot(r.t,squeeze(r.torque(:,1,:))*1e3);ylabel('Body x torque (mN m)');grid on;
for a=findall(f,'Type','axes')'
    xlabel(a,'Time (s)');xline(a,c.faultStart,':','HandleVisibility','off');xline(a,c.faultEnd,':','HandleVisibility','off');
end
title(tl,strrep(sprintf('%s | %s | seed %d',c.mode,c.scenario,c.seed),'_',' '));
exportgraphics(f,path,'Resolution',140);close(f);
end
