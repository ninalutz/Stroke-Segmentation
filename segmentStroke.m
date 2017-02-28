function [ segpoints, segtypes ] = segmentStroke( stroke )
    % Switch off some specific warnings from regress
    warning('off', 'stats:regress:RankDefDesignMat');
    warning('off', 'MATLAB:rankDeficientMatrix');
    
    %Use these booleans to do the paper implementation (r2implement =
    %false) and control if you want the default paper parameters or my
    %optimized ones
    r2implement = true;
    optimized = true;

    if optimized== false
        %%Default
        smoothingWindow = 5;
        tangentWindow = 11;
        speedThreshold1 = .25;
        speedThreshold2 = .8;
        curvatureThreshold = .75;
        minCornerDist = 50;
        minArcAngle = 36;
    end
    
    if optimized == true
        if r2implement == true
            %R2 values
            smoothingWindow = 6;
            tangentWindow = 15;
            speedThreshold1 = .65;
            speedThreshold2 = .8;
            curvatureThreshold = .75;
            minCornerDist = 50;
            minArcAngle = 6;
        else
            %Paper values
            smoothingWindow = 6;
            tangentWindow = 25;
            speedThreshold1 = .85;
            speedThreshold2 = .8;
            curvatureThreshold = .45;
            minCornerDist = 100;
            minArcAngle = 30;
        end
    end
    
    


    numStrokes = size(stroke.x);
    numStrokes = numStrokes(1);
    
%Step 1: Make array of arc lengths
     arcLengths = zeros(1, numStrokes);
     for i = 2:size(stroke.x)
         arcLengths(i) = arcLengths(i-1)+distance(stroke.x(i-1), stroke.y(i-1), stroke.x(i), stroke.y(i));
     end
     
%Step 2: Make an array of pen speeds
     penSpeeds = zeros(1, numStrokes);
     for i = 1:numStrokes
         penSpeeds(i) = penSpeed(i);
     end
     
%Step 3: Make an array of tangents
     tangents = zeros(1, numStrokes);
     for i = 1:numStrokes
         tan = tangent(i);
         tangents(i) = tan(2);
     end
     

%Step 4: Define curvature
     %convert slopes to degrees
     angles = radtodeg(atan(tangents));
     angles = correctAngleCurve(angles);
     curvatures = zeros(1, numStrokes);
     for i= 1:numStrokes
         curve = curvature(i);
         curvatures(i) = curve(2);
     end

%%Step 5: Find corners
     speeds = [];
     curves = [];
     avgSpeed = arcLengths(numStrokes)/(stroke.t(numStrokes) - stroke.t(1));
     
     %%Find minima by finding the peaks of the negative penSpeeds array
     [speedPeaks, speedLocations] = findpeaks(-penSpeeds);
     %change sign back
     speedPeaks = -speedPeaks;

     for i=1:size(speedPeaks, 2)
         if speedPeaks(i) < speedThreshold1*avgSpeed
             speeds = [speeds, speedLocations(i)];
         end
     end

     [curvePeaks, curveLocations] = findpeaks(curvatures);
     for i=1:size(curvePeaks,2)
         if curvePeaks(i) > curvatureThreshold && penSpeeds(curveLocations(i)) < speedThreshold2*avgSpeed
                 curves = [curves, curveLocations(i)];
         end
     end

%%Step 6: Merge and combine curves and speeds
     segments = [curves, speeds];
     mergeSegments = segments;
     for i = 1:size(segments, 2)
         for j = 1:size(segments, 2)
             if i == j
                 break
             end
             x1 = stroke.x(segments(i));
             x2 = stroke.x(segments(j));
             y1 = stroke.y(segments(i));
             y2 = stroke.y(segments(j));
             if distance(x1, y1, x2, y2) < minCornerDist
                 mergeSegments = mergeSegments(mergeSegments ~= segments(j));
             end
         end
         
         x1 = stroke.x(segments(i));
         y1 = stroke.y(segments(i));
         
         %%Check the begining and end edge cases   
         x2 = stroke.x(1);
         y2 = stroke.y(1);
         if distance(x1, y1, x2, y2) < minCornerDist
            mergeSegments = mergeSegments(mergeSegments ~= segments(i));
         end
         
         x2 = stroke.x(numStrokes);
         y2 = stroke.y(numStrokes);
         if distance(x1, y1, x2, y2) < minCornerDist
            mergeSegments = mergeSegments(mergeSegments ~= segments(i));
         end
     end
     %update segments
     segments = mergeSegments


     %%Step 7: Classify
     
     segpoints = sort(transpose(segments));
     %default to lines
     segtypes = zeros(size(segpoints, 1) + 1, 1);
    
     %need to iterate through all strokes
     allSegpoints = vertcat(1, segpoints, numStrokes);
     
     for i = 1:size(segpoints) + 1
         %linear residuals
         y = stroke.y(allSegpoints(i):allSegpoints(i+1));
         X = [ones(allSegpoints(i+1) - allSegpoints(i) + 1, 1), stroke.x(allSegpoints(i):allSegpoints(i+1))];
         [b, bint, r, rint, stats] = regress(y, X);
         lineres = sum(r);
         
         %circular residuals
         for j=1:size(segpoints)+1
             [xc,yc,R,a] = circfit(stroke.x, stroke.y);
             circr(j, 1) = distance(stroke.x(j), stroke.y(j), xc, yc) - R;
         end
         circres = sum(circr);
         
         %if the circular residual is less than linear, do some geometry
         %and see if it classifies as an arc
         if circres < lineres
             [xc,yc,R,a] = circfit(stroke.x, stroke.y);
             
             %Draw two lines from the circle to the points
             coefs = polyfit([stroke.x(i), xc], [stroke.y(i), yc], 1);
             coefs2 = polyfit([stroke.x(i+1), xc], [stroke.y(i+1), yc], 1);
             inters = linecirc(coefs(1), coefs(2), xc, yc, R);
             inters2 = linecirc(coefs2(1), coefs2(2), xc, yc, R);
             
             AB = distance(inters(1), inters(2), inters2(1), inters2(2));
             
             %Find the angle and compare to see if it's an arc
             subtend = radtodeg(atan(AB/2))*2;
             if subtend > minArcAngle
                   segtypes(i) = 1;
             end
         end
         
      %%%%ALTERNATIVE IMPLEMENTATION  
       if(r2implement)
        %If the R^2 value is statistically significant, than it is an arc
         if stats(1) < .1
            segtypes(i) = 1;
         end
       end

     end

    %helper functions
    function distanceFormula = distance(x1, y1, x2, y2)
        distanceFormula = sqrt((x2-x1)^2 + (y2-y1)^2);
    end

    function speed = penSpeed(i)
        %define speed of point based on points on both sides
        sideStroke = floor(smoothingWindow/2); %want round down, take closer points
        
        %check cases to see if we're at the start or end of symbol
        if i<1+sideStroke
            speed = penSpeed(1+sideStroke);

        elseif i > numStrokes - sideStroke
            speed = penSpeed(numStrokes- sideStroke);

        else
            dist = arcLengths(i + sideStroke) - arcLengths(i - sideStroke);
            time = stroke.t(i+sideStroke)-stroke.t(i-sideStroke);
            speed = dist/time;
        end
    end

     function tan = tangent(i)
         sideWindow = floor(tangentWindow/2); %want round down, points closer
         
         if i-sideWindow<1
             left = 1;
         else
             left = i-sideWindow;
         end
            
         if i+sideWindow>numStrokes
             right = numStrokes;
         else 
             right = i+sideWindow;
         end
         
         indicator = right - left + 1; %avoid wrong index
         
         X = [ones(indicator, 1), (1:indicator)']; 
         tan = regress(stroke.y(left:right), X);
     end

     function curve = curvature(i)
         sideWindow = floor(tangentWindow/2); %want round down again
         if i-sideWindow<1
             left = 1;
         else
             left = i-sideWindow;
         end
            
         if i+sideWindow>numStrokes
             right = numStrokes;
         else 
             right = i+sideWindow;
         end
         
         indicator = right - left + 1; %avoid wrong index
         
         X = [ones(indicator, 1), arcLengths(left:right)'];
         curve = regress(angles(left:right)', X);
     end


    end


