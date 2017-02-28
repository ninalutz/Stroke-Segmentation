function [ output_args ] = correctAngleCurve( angles )
    newAngles = zeros(size(angles));
    angles(1) = 0;
    for i = 2:size(angles, 2)
        delta = angles(i-1)-angles(i);
        %make it in the correct range
        if(delta >= 90)
            newAngles(i) = newAngles(i)-180;
        else
            newAngles(i) = delta;
        end
    end
    output_args = newAngles;
end