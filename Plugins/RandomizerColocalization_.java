import ij.*;
import ij.IJ.*;
import ij.WindowManager;
import ij.gui.GenericDialog;
import ij.measure.ResultsTable;
import ij.plugin.PlugIn;
import ij.text.TextPanel;
import ij.text.TextWindow;
import java.awt.geom.Point2D;

/**
 *
 * @author Florian Levet
 */
public class RandomizerColocalization_ implements PlugIn {
    private double m_width = Prefs.get("RandomizerColocalization_width.double", 640), m_height = Prefs.get("RandomizerColocalization_height.double", 640), m_nbSimulations = Prefs.get("RandomizerColocalization_nbSimulations.double", 10000);
    private double m_distanceMax = Prefs.get("RandomizerColocalization_distanceMax.double", 0);
    private String label1 = Prefs.get("RandomizerColocalization_label1.string", "Label_1");
    private String label2 = Prefs.get("RandomizerColocalization_label2.string", "Label_2");
    private String [] m_labels = {label1, label2};
    Point2D.Double[][] m_centroids;
    double[] m_colocRandomizedValues = new double[2];
    
    @Override
    public void run(String string) {
        if(!showDialog())
            return;
        
        m_centroids = new Point2D.Double[2][];
        
        java.awt.Window window = WindowManager.getWindow("Analysis_Results.csv");
        if(window==null){
            IJ.log("No Analysis_Results.csv found: can't perform randomization");
            return;
        }

        TextWindow tw = (TextWindow) window;
        ResultsTable rt = tw.getResultsTable();
        for(int n = 0; n < 2; n++){
            String nameLabelx = "X_" + m_labels[n] + "_microns", nameLabely = "Y_" + m_labels[n] + "_microns";
            int indexx = rt.getColumnIndex(nameLabelx), indexy = rt.getColumnIndex(nameLabely);
            double[] xs = rt.getColumnAsDoubles(indexx), ys = rt.getColumnAsDoubles(indexy);
            m_centroids[n] = new Point2D.Double[xs.length];
            for(int i = 0; i < xs.length; i++)
                m_centroids[n][i] = new Point2D.Double(xs[i], ys[i]);
        }
        
        for(int n = 0; n < 2; n++)
            randomizeColocForColor(n);
        
        TextWindow twRes = new TextWindow("Randomizer_Results", new String(), 800, 600);
        TextPanel tp = twRes.getTextPanel();
        String headings = "Coloc for Color 1 with randomization\tColoc for Color 2 with randomization";
        tp.setColumnHeadings(headings);
        String line = "" + m_colocRandomizedValues[0] + "\t" + m_colocRandomizedValues[1];
        tp.appendLine(line);
        twRes.setVisible(true);
    }

    public boolean showDialog() {
        GenericDialog gd = new GenericDialog("Colocalization randomizer");
        gd.addNumericField("Image_width_(microns)", m_width, 0);
        gd.addNumericField("Image_height_(microns)", m_height, 0);
        gd.addNumericField("Distance_max_colocalization_(microns)", m_distanceMax, 2);
        gd.addNumericField("#_Monte_Carlo_simulations", m_nbSimulations, 0);
        gd.addStringField("Name_of_label_1", label1);
        gd.addStringField("Name_of_label_2", label2);
        gd.showDialog();
        if (gd.wasCanceled()) {
            return false;
        }
        m_width = gd.getNextNumber();
        m_height = gd.getNextNumber();
        m_distanceMax = gd.getNextNumber();
        m_nbSimulations = gd.getNextNumber();
        m_labels[0] = gd.getNextString();
        m_labels[1] = gd.getNextString();
        
        Prefs.set("RandomizerColocalization_width.double", m_width);
        Prefs.set("RandomizerColocalization_height.double", m_height);
        Prefs.set("RandomizerColocalization_distanceMax.double", m_distanceMax);
    	Prefs.set("RandomizerColocalization_nbSimulations.double", m_nbSimulations);
    	Prefs.set("RandomizerColocalization_label1.string", m_labels[0]);
    	Prefs.set("RandomizerColocalization_label2.string", m_labels[1]);
        
        
        return true;
    }

    void randomizeColocForColor(int _idColor){
        int idOtherColor = (_idColor + 1) % 2;
        
        double[] percentColocPerSimu = new double[(int)m_nbSimulations];
        
        Point2D.Double[] randomizedPoints = new Point2D.Double[m_centroids[idOtherColor].length];
        for(int i = 0; i < m_centroids[idOtherColor].length; i++)
            randomizedPoints[i] = new Point2D.Double();
        
        for(int n = 0; n < m_nbSimulations; n++){
            for(int i = 0; i < m_centroids[idOtherColor].length; i++){
                double x = Math.random() * m_width, y = Math.random() * m_height;
                randomizedPoints[i].setLocation(x, y);
            }
            double nbColoc = 0.;
            for(int i = 0; i < m_centroids[_idColor].length; i++){
                boolean coloc = false;
                for(int j = 0; j < randomizedPoints.length && !coloc; j++){
                    double d = m_centroids[_idColor][i].distance( randomizedPoints[j] );
                    coloc = d < m_distanceMax;
                }
                if(coloc)
                    nbColoc += 1.;
            }
            percentColocPerSimu[n] = nbColoc / (double)m_centroids[_idColor].length;
        }
        
        m_colocRandomizedValues[_idColor] = 0.;
        for(int n = 0; n < m_nbSimulations; n++)
            m_colocRandomizedValues[_idColor] += percentColocPerSimu[n] / m_nbSimulations;
        m_colocRandomizedValues[_idColor] *= 100.;
    }
}
