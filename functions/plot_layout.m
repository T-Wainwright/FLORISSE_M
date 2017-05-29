function [ ] = plot_layout( wtRows,site,turbType,turbines,wakes )

    turbIF = [turbines.LocIF];
    turbWF = [turbines.LocWF];
    YawIfs = [turbines.YawIF];
    YawWfs = [turbines.YawWF];
    Nt     = size(turbWF,2);
    
    % Plot the turbines in the inertial frame
    subplot(1,2,1);
    
    % Plot the turbines
    for j = 1:Nt
        plot(turbIF(1,j)+ 0.5*[-1, 1]*turbType.rotorDiameter*sin(YawIfs(j)),...
             turbIF(2,j)+ 0.5*[1, -1]*turbType.rotorDiameter*cos(YawIfs(j)),'LineWidth',3); hold on;
        text(turbIF(1,j)+30,turbIF(2,(j))+20,['T' num2str(j)]);
    end;

    % Set labels and image size
    ylabel('Internal y-axis [m]');
    xlabel('Internal x-axis [m]');
    title('Inertial frame');
    grid on; axis equal; hold on;
    xlim([min(turbIF(1,:))-500 max(turbIF(1,:)+500)]);
    ylim([min(turbIF(2,:))-500 max(turbIF(2,:)+500)]);
    
    % Plot wind direction
    quiver(min(turbIF(1,:))-400,mean(turbIF(2,:)),site.uInfIf*30,site.vInfIf*30,'LineWidth',1,'MaxHeadSize',5);
    text(min(turbIF(1,:))-400,mean(turbIF(2,:))-50,'U_{inf}');
    
    % Plot the turbines in the wind aligned frame
    subplot(1,2,2);   
    for j = 1:Nt
        plot(turbWF(1,j) + 0.5*[-1, 1]*turbType.rotorDiameter*sin(YawWfs(j)),...
             turbWF(2,j) + 0.5*[1, -1]*turbType.rotorDiameter*cos(YawWfs(j)),'LineWidth',3); hold on;
        text(turbWF(1,j) +30,turbWF(2,j) +20,['T' num2str(j)]);
    end;
    % Plot the wake centerLines
    for TRow = 1:length(wtRows)
        for Tnum = wtRows{TRow}
            hold on;
            plot([turbWF(1,Tnum) wakes(Tnum).centerLine(1,:)],[turbWF(2,Tnum) wakes(Tnum).centerLine(2,:)],'--','DisplayName','Wake Centerline');
        end;
    end;
    ylabel('Aligned y-axis [m]');
    xlabel('Aligned x-axis [m]');
    title('Wind-aligned frame');
    grid on; axis equal; hold on;
    xlim([min(turbWF(1,:))-500, max(turbWF(1,:))+500]);
    ylim([min(turbWF(2,:))-500, max(turbWF(2,:))+500]);
    quiver(min(turbWF(1,:))-400,mean(turbWF(2,:)),site.uInfWf*30,site.vInfWf*30,'LineWidth',1,'MaxHeadSize',5);
    text(min(turbWF(1,:))-400,mean(turbWF(2,:))-50,'U_{inf}');
end