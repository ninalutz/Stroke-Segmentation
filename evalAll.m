function h = evalAll(strokes)
    % h = evalAll(strokes)
    for i = 1:length(strokes);
        disp(sprintf('stroke %i',i));
        subplot_tight(3,4,i,[0.05 0.05]);

        [corners segtypes] = segmentStroke(strokes(i));
        h = showSegmentation(strokes(i),corners,segtypes);
    end
end
            
